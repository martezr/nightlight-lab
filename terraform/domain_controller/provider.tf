terraform {
  required_providers {
    nightlight = {
      source  = "registry.terraform.io/martezr/nightlight"
      version = "0.1.0"
    }
  }
}

provider "nightlight" {
  endpoint = "http://10.0.0.239"
  username = "root"
  password = "nightlight"
}

