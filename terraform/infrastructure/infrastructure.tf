resource "nightlight_wan_router" "external" {
  wan_ip_address = "10.0.0.49"
  wan_netmask    = "255.255.255.0"
  wan_gateway    = "10.0.0.1"
  static_routes = [
    {
      destination = "192.168.128.0/23"
      gateway     = "172.16.100.2"
    },
    {
      destination = "192.168.130.0/23"
      gateway     = "172.16.100.3"
    }
  ]
}

// US East 1 Site
resource "nightlight_site" "us-east-1" {
  name     = "us-east-1"
  location = "Virginia"
  topology = "single-bridge"
}

resource "nightlight_subnet" "us-east-1-management" {
  name          = "management"
  description   = "management subnet"
  cidr_block    = "192.168.128.0/24"
  gateway       = "192.168.128.1"
  dhcp_server   = true
  ip_pool_range = "192.168.128.100-192.168.128.200"
  dns_servers   = ["4.2.2.2", "8.8.8.8"]
  site_id       = nightlight_site.us-east-1.id
  vlan_id       = 1
}

resource "nightlight_subnet" "us-east-1-compute" {
  name          = "compute"
  description   = "compute subnet"
  cidr_block    = "192.168.129.0/24"
  gateway       = "192.168.129.1"
  dhcp_server   = true
  ip_pool_range = "192.168.129.100-192.168.129.200"
  dns_servers   = ["4.2.2.2", "8.8.8.8"]
  site_id       = nightlight_site.us-east-1.id
  vlan_id       = 2
}

// US West 1 Site
resource "nightlight_site" "us-west-1" {
  name       = "us-west-1"
  location   = "California"
  topology   = "single-bridge"
  depends_on = [nightlight_site.us-east-1]
}

resource "nightlight_subnet" "us-west-1-management" {
  name          = "us-west-1-management"
  description   = "management subnet"
  cidr_block    = "192.168.130.0/24"
  gateway       = "192.168.130.1"
  dhcp_server   = true
  ip_pool_range = "192.168.130.100-192.168.130.200"
  dns_servers   = ["4.2.2.2", "8.8.8.8"]
  site_id       = nightlight_site.us-west-1.id
  vlan_id       = 3
}

resource "nightlight_subnet" "us-west-1-compute" {
  name          = "us-west-1-compute"
  description   = "compute subnet"
  cidr_block    = "192.168.131.0/24"
  gateway       = "192.168.131.1"
  dhcp_server   = true
  ip_pool_range = "192.168.131.100-192.168.131.200"
  dns_servers   = ["4.2.2.2", "8.8.8.8"]
  site_id       = nightlight_site.us-west-1.id
  vlan_id       = 4
}

resource "nightlight_image" "ubuntu24" {
  name             = "Ubuntu 24.04 LTS"
  description      = "Ubuntu 24.04 LTS"
  operating_system = "Ubuntu 24.04 LTS"
  source_type      = "url"
  source_url       = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  format           = "raw"
  file_name        = "ubuntu-24.04-server-cloudimg-amd64.img"
  datastore_id     = "defaultdatastore"
}

resource "nightlight_image" "ubuntu22" {
  name             = "Ubuntu 22.04 LTS"
  description      = "Ubuntu 22.04 LTS"
  operating_system = "Ubuntu 22.04 LTS"
  source_type      = "url"
  source_url       = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  format           = "raw"
  file_name        = "ubuntu-22.04-server-cloudimg-amd64.img"
  datastore_id     = "defaultdatastore"
}

resource "nightlight_content_library" "base_images" {
  name          = "demo"
  description   = "Base images for provisioning"
  depot_url     = "http://10.0.0.173:8080"
  datastore_id  = "defaultdatastore"
  depot_token   = "ad5182d9-c45c-488d-9e1d-ad716f4e45ff"
  sync_interval = "manual"
}