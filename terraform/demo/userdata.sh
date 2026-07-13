#cloud-config

# System hostname
hostname: ${hostname}
fqdn: ${fqdn}

# Disable root SSH login
disable_root: false

chpasswd:
  expire: false
  users:
    - name: root
      password: Password123#
      type: text

ssh_pwauth: true

apt:
  preserve_sources_list: false

  primary:
    - arches: [default]
      uri: http://10.0.0.78:8080/packages/ubuntu/

  security:
    - arches: [default]
      uri: http://10.0.0.78:8080/packages/ubuntu-security/

# Update and upgrade packages on first boot
package_update: true
package_upgrade: true

# Install packages
packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - ufw
  - unattended-upgrades

write_files:
  # Prevent cloud-init from changing networking after first boot
  - path: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    owner: root:root
    permissions: "0644"
    content: |
      network: {config: disabled}

  # Configure DHCP via Netplan
  - path: /etc/netplan/99-dhcp.yaml
    owner: root:root
    permissions: "0600"
    content: |
      network:
        version: 2
        ethernets:
          enp1s0:
            dhcp4: true

runcmd:
  - [ netplan, apply ]
  - sleep 15
  - sh -c 'curl -fsSL http://169.254.169.253/install-agent.sh | sh'

network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: true
