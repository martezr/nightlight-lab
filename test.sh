#!/bin/bash
cd ..
cd terraform-provider-nightlight
go install
make install-local
cd ..
cd tftest
#rm -rf .terraform
#rm .terraform.lock.hcl
#terraform init
#terraform plan
