terraform {
  required_providers {
    nightlight = {
      source  = "registry.terraform.io/martezr/nightlight"
      version = "0.1.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "nightlight" {
  endpoint = "http://10.0.0.239"
  username = "root"
  password = "nightlight"
}

# Configure the OpenStack Provider
provider "openstack" {
  user_name   = "admin"
  tenant_name = "admin"
  password    = "Password123#"
  auth_url    = "http://192.168.128.250:5000/v3"
  region      = "RegionOne"
}