data "nightlight_site" "example" {
  name = "us-east-1"
}

data "nightlight_subnet" "management" {
  name = "management"
}

data "nightlight_subnet" "compute" {
  name = "compute"
}

data "nightlight_image" "windows2016" {
  name = "Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.iso"
}

data "nightlight_image" "virtio" {
  name = "virtio-win-0.1.285.iso"
}


output "ip_addresses" {
  value = nightlight_instance.windows2016.guest_ip_addresses
}

resource "nightlight_instance" "windows2016" {
  name           = "windows2016"
  cpu_cores      = 4
  cpu_sockets    = 2
  memory_mb      = 8192
  datastore_id   = "defaultdatastore"
  site_id        = data.nightlight_site.example.id
  win_autoattend = templatefile("${path.module}/autounattend.xml", {
    hostname = "windows2016"
  })
  wait_for_guest = true
  guest_ready_timeout = 600
  instance_type  = "virtualmachine"
  cdroms = [{
    index_number = 0
    boot_order   = 2
    connected    = true
    path         = data.nightlight_image.windows2016.path
  },
{
    index_number = 0
    boot_order   = 3
    connected    = true
    path         = data.nightlight_image.virtio.path
  }
  ]

  storage_disks = [
    {
      index_number = 0
      boot_order   = 1
      size_gb      = 60
      bus_type     = "virtio"
      datastore_id = "defaultdatastore"
    }
  ]

  network_interfaces = [
    {
      index_number = 0
      boot_order   = 4
      bridge_name  = data.nightlight_site.example.bridges[0]
      subnet_id    = data.nightlight_subnet.management.id
      model        = "virtio"
      connected    = true
    }
  ]
}