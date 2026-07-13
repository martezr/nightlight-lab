#!/bin/bash

sudo apt-get install -y salt-api python3-pip

sudo salt-pip install CherryPy

sudo mkdir -p /etc/salt/pki/api

sudo openssl req \
-x509 \
-nodes \
-days 3650 \
-newkey rsa:4096 \
-keyout /etc/salt/pki/api/api.key \
-out /etc/salt/pki/api/api.crt \
-subj "/C=US/ST=IL/L=Chicago/O=Kalvar/OU=IT/CN=$(hostname -f)"

sudo chmod 644 /etc/salt/pki/api/api.key
sudo chmod 644 /etc/salt/pki/api/api.crt

cat <<EOF | sudo tee /etc/salt/master.d/api.conf
external_auth:
  auto:
    apiuser:
      - .*
      - '@runner'
      - '@wheel'

rest_cherrypy:
  host: 0.0.0.0
  port: 8000

  ssl_crt: /etc/salt/pki/api/api.crt
  ssl_key: /etc/salt/pki/api/api.key

  thread_pool: 100
  socket_queue_size: 30

  debug: False

netapi_enable_clients:
  - local
  - local_async
  - runner
  - runner_async
  - wheel
EOF

cat <<EOF | sudo tee /etc/salt/master.d/auto.conf
auto_accept: True
EOF

cat <<EOF | sudo tee /etc/salt/master.d/git.conf
fileserver_backend:
  - roots
  - gitfs

gitfs_provider: pygit2
gitfs_remotes:
  - http://10.0.0.78:8080/git/tftest.git:
      - base: main
      - root: states
      - mountpoint: salt://

gitfs_update_interval: 120
EOF

sudo systemctl restart salt-master
sudo systemctl enable salt-master

sudo systemctl restart salt-api
sudo systemctl enable salt-api

sudo salt-key -A -y

sudo salt-run fileserver.update
sudo salt-run fileserver.file_list

sudo mkdir -p /srv/salt