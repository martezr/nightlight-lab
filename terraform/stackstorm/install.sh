#!/bin/bash

cat <<EOF > /opt/stackstorm/configs/salt.yaml
api_url: https://192.168.128.103:8000
eauth: auto
password: password
username: apiuser
verify_ssl: false
EOF

st2 pack install https://github.com/martezr/nightlight-lab.git

sudo st2ctl reload --register-configs

sudo mkdir -p /stackstorm
sudo chmod -R 777 /stackstorm

# Install Go
GO_VERSION=1.24.5
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
export PATH="/usr/local/go/bin:$PATH"
echo 'export PATH="/usr/local/go/bin:$PATH"' >> ~/.bashrc

# Build the nightlight Terraform provider and configure dev_overrides
export GOBIN=/stackstorm

git clone https://github.com/martezr/terraform-provider-nightlight.git /tmp/terraform-provider-nightlight
cd /tmp/terraform-provider-nightlight
go install .

cat <<EOF > /home/stanley/.terraformrc
provider_installation {
  filesystem_mirror {
    path    = "/home/stanley/.terraform.d/plugins"
    include = ["martezr/nightlight"]
  }

  direct {
    exclude = ["martezr/nightlight"]
  }
}
EOF

mkdir -p /home/stanley/.terraform.d/plugins/registry.terraform.io/martezr/nightlight/0.1.0/linux_amd64
cp /root/go/bin/terraform-provider-nightlight /home/stanley/.terraform.d/plugins/registry.terraform.io/martezr/nightlight/0.1.0/linux_amd64/terraform-provider-nightlight_v1.0.0

cp /home/stanley/.terraformrc /root/.terraformrc
echo 'export TF_CLI_CONFIG_FILE=/home/stanley/.terraformrc' > /etc/profile.d/terraform.sh
chmod +x /etc/profile.d/terraform.sh

# Remove any stale lock files so Terraform uses the dev_override instead of the registry
find /stackstorm -name ".terraform.lock.hcl" -delete
find /stackstorm -name ".terraform" -type d -exec rm -rf {} +