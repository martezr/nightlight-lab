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
GOBIN="$(go env GOPATH)/bin"

git clone https://github.com/martezr/terraform-provider-nightlight.git /tmp/terraform-provider-nightlight
cd /tmp/terraform-provider-nightlight
go install .

cat <<EOF > ~/.terraformrc
provider_installation {
  dev_overrides {
    "martezr/nightlight" = "${GOBIN}"
  }
  direct {}
}
EOF