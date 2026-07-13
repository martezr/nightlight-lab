# Look up an image by name and deploy an instance from it.

output "ip_addresses" {
  value = nightlight_instance.web.guest_ip_addresses
}

resource "nightlight_instance" "web" {
  name         = "web-01"
  cpu_cores    = 2
  cpu_sockets  = 1
  memory_mb    = 2048
  datastore_id = "defaultdatastore"
  user_data = templatefile("${path.module}/userdata.sh", {
    hostname = "web-01"
    fqdn     = "web-01.rmslab.net"
  })
  site_id       = nightlight_site.example.id
  instance_type = "virtualmachine"
  storage_disks = [
    {
      index_number  = 0
      boot_order    = 1
      size_gb       = 20
      bus_type      = "virtio"
      datastore_id  = "defaultdatastore"
      existing_path = nightlight_image.ubuntu24.path
    }
  ]

  network_interfaces = [
    {
      index_number = 0
      boot_order   = 2
      bridge_name  = nightlight_site.example.bridges[0]
      subnet_id    = nightlight_subnet.management.id
      model        = "virtio"
      connected    = true
    },
    {
      index_number = 1
      boot_order   = 3
      bridge_name  = nightlight_site.example.bridges[0]
      subnet_id    = nightlight_subnet.compute.id
      model        = "virtio"
      connected    = true
    }
  ]
}

resource "nightlight_instance" "db" {
  name         = "db-01"
  cpu_cores    = 2
  cpu_sockets  = 1
  memory_mb    = 2048
  datastore_id = "defaultdatastore"
  user_data = templatefile("${path.module}/userdata.sh", {
    hostname = "db-01"
    fqdn     = "db-01.rmslab.net"
  })
  site_id       = nightlight_site.example.id
  instance_type = "virtualmachine"
  storage_disks = [
    {
      index_number  = 0
      boot_order    = 1
      size_gb       = 20
      bus_type      = "virtio"
      datastore_id  = "defaultdatastore"
      existing_path = nightlight_image.ubuntu24.path
    }
  ]

  network_interfaces = [
    {
      index_number = 0
      boot_order   = 2
      bridge_name  = nightlight_site.example.bridges[0]
      subnet_id    = nightlight_subnet.management.id
      model        = "virtio"
      connected    = true
    },
    {
      index_number = 1
      boot_order   = 3
      bridge_name  = nightlight_site.example.bridges[0]
      subnet_id    = nightlight_subnet.compute.id
      model        = "virtio"
      connected    = true
    }
  ]
}
