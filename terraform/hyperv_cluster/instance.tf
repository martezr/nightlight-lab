variable "instance_count" {
  description = "Number of instances to deploy"
  type        = number
  default     = 2
}

variable "instance_name_prefix" {
  description = "Prefix for instance names"
  type        = string
  default     = "hyperv"
}

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
  name = "win2k16"
}

output "ip_addresses" {
  value = { for k, v in nightlight_instance.hyperv : k => v.guest_ip_addresses }
}

resource "nightlight_instance" "hyperv" {
  count          = var.instance_count
  name           = format("%s%02d", var.instance_name_prefix, count.index + 1)
  cpu_cores      = 4
  cpu_sockets    = 2
  memory_mb      = 8192
  datastore_id   = "defaultdatastore"
  site_id        = data.nightlight_site.example.id
  wait_for_guest = true
  guest_ready_timeout = 600
  instance_type  = "virtualmachine"
  cdroms = []

  storage_disks = [
    {
      index_number = 0
      boot_order   = 1
      size_gb      = 65
      bus_type     = "virtio"
      datastore_id = "defaultdatastore"
      existing_path = data.nightlight_image.windows2016.path
    },
    {
      index_number = 0
      boot_order   = 2
      size_gb      = 100
      bus_type     = "virtio"
      datastore_id = "defaultdatastore"
    }
  ]

  network_interfaces = [
    {
      index_number = 0
      boot_order   = 3
      bridge_name  = data.nightlight_site.example.bridges[0]
      subnet_id    = data.nightlight_subnet.management.id
      model        = "virtio"
      connected    = true
    }
  ]
}
