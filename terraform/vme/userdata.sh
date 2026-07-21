## template: jinja
#cloud-config

# System hostname
hostname: ${hostname}
fqdn: ${fqdn}

# Disable root SSH login
disable_root: false

users:
  - default
  - name: mreed
    groups: [sudo, wheel]
    shell: /bin/bash
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL

chpasswd:
  expire: false
  users:
    - name: root
      password: Password123#
      type: text
    - name: mreed
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
  - ufw
  - unattended-upgrades


write_files:
  # 1. Block cloud-init from overwriting network settings on future boots
  - path: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    owner: root:root
    permissions: '0644'
    content: |
      network:
        config: disabled

  # 2. Write the static Netplan configuration block
  - path: /etc/netplan/99-static-ip.yaml
    owner: root:root
    permissions: '0600'
    content: |
      network:
        version: 2
        ethernets:
          ens1:
            dhcp4: false
            addresses:
              - {{ds.meta_data.local_ipv4 }}/24
            routes:
              - to: default
                via: {{ ds.meta_data.network.interfaces.macs[ds.meta_data.mac]['gateway-ipv4'] }}
              - to: 169.254.0.0/16
                scope: link
            nameservers:
              addresses:
                - 4.2.2.2


runcmd:
  # 3. Apply the changes immediately during the initial boot sequence
  - rm -f /etc/netplan/50-cloud-init.yaml
  - netplan generate
  - netplan apply
  - sleep 15
  - sh -c 'curl -fsSL http://169.254.169.253/install-agent.sh | sh'

network:
  version: 2
  ethernets:
    ens1:
      dhcp4: false
      addresses: [{{ds.meta_data.local_ipv4 }}/24]
      gateway4: {{ ds.meta_data.network.interfaces.macs[ds.meta_data.mac]['gateway-ipv4'] }}
      nameservers:
        addresses: [4.2.2.2]
      routes:
        - to: 169.254.0.0/16
          scope: link
        - to: default
          via: {{ ds.meta_data.network.interfaces.macs[ds.meta_data.mac]['gateway-ipv4'] }}
