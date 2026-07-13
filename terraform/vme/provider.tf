terraform {
  required_providers {
    nightlight = {
      source  = "registry.terraform.io/martezr/nightlight"
      version = "0.1.0"
    }
    hpe = {
      source  = "HPE/hpe"
      version = ">= 1.5.0"
    }
  }
}

provider "nightlight" {
  endpoint = "http://10.0.0.239"
  username = "root"
  password = "nightlight"
}

provider "hpe" {
  # Provide morpheus block if you want to create morpheus resources
  morpheus {
    url      = "https://${local.vmemanager}"
    username = "rmadmin"
    password = "Password123#"
    insecure = true
  }
}

locals {
  vmemanager = "192.168.128.243"
}