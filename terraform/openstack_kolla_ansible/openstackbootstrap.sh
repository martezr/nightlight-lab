#!/bin/bash
sudo hostnamectl set-hostname ${hostname}
sudo sed -i "s/127.0.1.1.*/127.0.1.1 ${fqdn} ${hostname}/" /etc/hosts

export ANSIBLE_FORKS=20
sudo mkdir /etc/ansible

sudo tee /etc/ansible/ansible.cfg > /dev/null <<EOF
[defaults]
host_key_checking = False
pipelining = True
forks = 100
EOF

sudo systemctl stop ufw
sudo systemctl disable ufw

# Configure secondary disk for Cinder
sudo pvcreate /dev/vdb
sudo vgcreate cinder-volumes /dev/vdb

sudo apt update -y

sudo apt install -y git python3-dev libffi-dev gcc libssl-dev \
    python3-venv python3-pip python3-dbus libdbus-1-dev libdbus-glib-1-dev \
    build-essential libpython3-dev chrony nfs-common iputils-ping

#sudo apt install -y git python3-dev libffi-dev gcc libssl-dev libdbus-glib-1-dev

#sudo apt install -y python3-venv

python3 -m venv /ostackinstall/venv
source /ostackinstall/venv/bin/activate

pip install -U pip
pip install docker dbus-python
pip install -U 'ansible-core>=2.16,<2.18'

pip install git+https://opendev.org/openstack/kolla-ansible@stable/2025.2


sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla

cp -r /ostackinstall/venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla

cp /ostackinstall/venv/share/kolla-ansible/ansible/inventory/all-in-one /etc/kolla/

kolla-ansible install-deps

kolla-genpwd

# Update /etc/kolla/passwords.yml with the keystone_admin_password
sed -i 's/^keystone_admin_password:.*/keystone_admin_password: Password123#/' /etc/kolla/passwords.yml

# Configure SSL certificates for OpenStack services
CERT_DIR="/etc/kolla/certificates"
CA_DIR="$${CERT_DIR}/ca"

DAYS_CA=3650
DAYS_CERT=825

echo "[+] Creating directory structure..."
sudo mkdir -p $${CERT_DIR}
sudo mkdir -p $${CA_DIR}

cd /tmp

echo "[+] Generating CA key..."
openssl genrsa -out ca.key 4096

echo "[+] Generating CA certificate..."
openssl req -x509 -new -nodes \
-key ca.key \
-sha256 -days $${DAYS_CA} \
-subj "/C=US/ST=State/L=City/O=OpenStack/OU=Kolla/CN=Kolla-CA" \
-out ca.crt

echo "[+] Generating server key..."
openssl genrsa -out haproxy.key 4096

echo "[+] Creating OpenSSL config with SAN..."
cat > openssl-san.cnf <<EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C=US
ST=State
L=City
O=OpenStack
OU=Kolla
CN=${fqdn}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${fqdn}
IP.1 = ${ip_address}
EOF

echo "[+] Generating CSR..."
openssl req -new \
-key haproxy.key \
-out haproxy.csr \
-config openssl-san.cnf

echo "[+] Signing certificate with CA..."
openssl x509 -req \
-in haproxy.csr \
-CA ca.crt \
-CAkey ca.key \
-CAcreateserial \
-out haproxy.crt \
-days $${DAYS_CERT} \
-sha256 \
-extensions req_ext \
-extfile openssl-san.cnf

echo "[+] Creating HAProxy PEM file..."
cat haproxy.crt haproxy.key > haproxy.pem

echo "[+] Installing certificates to Kolla directory..."
sudo cp haproxy.pem $${CERT_DIR}/
sudo cp ca.crt $${CA_DIR}/

echo "[+] Setting permissions..."
sudo chmod 600 $${CERT_DIR}/haproxy.pem
sudo chmod 644 $${CA_DIR}/ca.crt

echo "[+] Cleaning up temp files..."
rm -f ca.key ca.srl haproxy.key haproxy.csr haproxy.crt openssl-san.cnf

echo ""
echo "[✔] TLS setup complete!"
echo ""

# ## Create CA Certificate
sudo tee -a /etc/kolla/globals.yml > /dev/null <<EOF
kolla_base_distro: "ubuntu"
openstack_release: "2025.2"

network_interface: "enp1s0"          # your management NIC
neutron_external_interface: "enp2s0" # NIC with no IP, for external/public net

kolla_internal_vip_address: "192.168.128.250"   # any free IP on your management subnet

enable_haproxy: "yes"
enable_keepalived: "yes"

nova_compute_virt_type: "kvm"   # or "qemu" if nested virtualization isn't available

enable_cinder: "yes"          # optional, needed for block storage
enable_cinder_backend_lvm: "yes"   # if you set up an LVM VG named cinder-volumes
EOF


# sudo tee -a /etc/kolla/globals.yml > /dev/null <<EOF

# #workaround_ansible_issue_8743: yes
# kolla_base_distro: "ubuntu"
# kolla_install_type: "binary"

# # Single-node optimizations
# enable_haproxy: "no"
# enable_keepalived: "no"
# enable_cinder: "no"
# enable_ceph: "no"
# enable_fluentd: "no"
# enable_manila: "no"
# enable_mariadb_cluster: "no"
# enable_proxysql: "no"

# # Disable unnecessary services
# enable_barbican: "no"
# enable_magnum: "no"
# enable_trove: "no"
# enable_sahara: "no"
# enable_heat: "no"
# enable_ironic: "no"
# enable_swift: "no"

# # Optional: disable telemetry (saves resources)
# enable_ceilometer: "no"
# enable_gnocchi: "no"
# enable_aodh: "no"

# enable_neutron_dvr: "no"
# enable_neutron_qos: "no"
# enable_neutron_fwaas: "no"
# enable_neutron_vpnaas: "no"

# # Network
# network_interface: "enp1s0"
# neutron_external_interface: "enp2s0"
# kolla_internal_vip_address: "${ip_address}"

# neutron_physical_networks: "physnet1"
# enable_neutron_provider_networks: "yes"

# # Neutron flat network
# #neutron_plugin_agent: "openvswitch"
# #enable_neutron_provider_networks: "yes"
# #neutron_physical_networks: "physnet1"
# #neutron_flat_networks: "physnet1"
# EOF


##### Backup of globals.yml for reference

# Optional: configure Neutron with Open vSwitch and provider network
# Neutron
#enable_neutron_provider_networks: "yes"
#neutron_type_drivers: "flat,vxlan"
#neutron_tenant_network_types: "vxlan"

# Bridge mapping
#neutron_bridge_mappings: "physnet1:br-ex"

#neutron_plugin_agent: "openvswitch"
#neutron_bridge_name: "br-ex"
#enable_neutron_provider_networks: "yes"
#neutron_physical_networks: "physnet1"
#neutron_flat_networks: "physnet1"
#kolla_external_vip_address: "192.168.3.236"
#kolla_enable_tls_external: "yes"

#enable_cinder: "yes"
#enable_cinder_backend_lvm: "yes"

# kolla_external_fqdn: "openstack.rmslab.net"
# kolla_copy_ca_into_containers: "yes"
# kolla_enable_tls_external: "yes"
# kolla_external_tls_cert: "/etc/kolla/certificates/haproxy.pem"

kolla-ansible bootstrap-servers -i /etc/kolla/all-in-one -e ansible_python_interpreter=/usr/bin/python3
kolla-ansible prechecks -i /etc/kolla/all-in-one -e ansible_python_interpreter=/usr/bin/python3
kolla-ansible deploy -i /etc/kolla/all-in-one -e ansible_python_interpreter=/usr/bin/python3

sudo chmod 0644 /etc/kolla/passwords.yml
#sudo chown -R ubuntu /ostackinstall/venv
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/2025.2

kolla-ansible post-deploy -i /etc/kolla/all-in-one -e ansible_python_interpreter=/usr/bin/python3

source /etc/kolla/admin-openrc.sh

sudo apt install python3-openstackclient -y

# openstack network create private-net
# openstack subnet create private-subnet   --network private-net   --subnet-range 192.168.200.0/24   --dns-nameserver 8.8.8.8
# openstack router create router1
# openstack router set router1 --external-gateway public
# openstack router add subnet router1 private-subnet



# openstack security group rule create --protocol icmp default
# openstack security group rule create --protocol tcp --dst-port 22 default
# openstack security group rule create --protocol tcp --dst-port 1:65535 default
# openstack security group rule create --protocol udp --dst-port 1:65535 default
# wget https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img

# openstack flavor create --public m1.tiny --id auto --ram 1024 --disk 5 --vcpus 1

# openstack server create   --image cirros   --flavor m1.tiny   --network private-net   --security-group default test-vm

# # FIP=$(openstack floating ip create -f value -c floating_ip_address public) && \
# # openstack server add floating ip test-vm $FIP && \
# # echo "Floating IP: $FIP"

cat /etc/kolla/passwords.yml | grep 'keystone_admin_password'