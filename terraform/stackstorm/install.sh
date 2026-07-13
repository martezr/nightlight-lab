#!/bin/bash

cat <<EOF > /opt/stackstorm/configs/salt.yaml
api_url: https://192.168.128.103:8000
eauth: auto
password: password
username: apiuser
verify_ssl: false
EOF

sudo st2ctl reload --register-configs