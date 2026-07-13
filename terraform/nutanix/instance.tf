data "nightlight_site" "example" {
  name = "us-east-1"
}

data "nightlight_subnet" "management" {
  name = "management"
}

data "nightlight_subnet" "compute" {
  name = "compute"
}


output "ip_addresses" {
  value = nightlight_instance.nutanix.guest_ip_addresses
}
data "nightlight_image" "nutanix_iso" {
  name = "phoenix.x86_64-fnd_5.6.1_patch-aos_6.8.1_ga.iso"
}

resource "nightlight_instance" "nutanix" {
  name           = "nutanix01"
  cpu_cores      = 8
  cpu_sockets    = 2
  memory_mb      = 32768
  datastore_id   = "defaultdatastore"
  site_id        = data.nightlight_site.example.id
  wait_for_guest = false
  instance_type  = "virtualmachine"
  cdroms = [{
    index_number = 0
    boot_order   = 4
    connected    = true
    path         = data.nightlight_image.nutanix_iso.path
  }]

  storage_disks = [
    {
      index_number = 0
      boot_order   = 1
      size_gb      = 60
      bus_type     = "sata"
      datastore_id = "defaultdatastore"
    },
    {
      index_number = 1
      boot_order   = 2
      size_gb      = 200
      bus_type     = "sata"
      datastore_id = "defaultdatastore"
    },
    {
      index_number = 2
      boot_order   = 3
      size_gb      = 200
      bus_type     = "sata"
      datastore_id = "defaultdatastore"
    }
  ]

  network_interfaces = [
    {
      index_number = 0
      boot_order   = 5
      bridge_name  = data.nightlight_site.example.bridges[0]
      subnet_id    = data.nightlight_subnet.management.id
      model        = "e1000"
      connected    = true
    },
    {
      index_number = 1
      boot_order   = 6
      bridge_name  = data.nightlight_site.example.bridges[0]
      subnet_id    = data.nightlight_subnet.compute.id
      model        = "e1000"
      connected    = true
    }
  ]
}

resource "nightlight_instance_boot_commands" "nutanix" {
  instance_id         = nightlight_instance.nutanix.id
  wait_for_guest      = false
  guest_ready_timeout = 300

  post_boot_commands = [
    // Wait for the VM to boot and the installer to launch
    {
      keys           = "",
      pause_after_ms = 180000
    },
    // Tab to IP address
    {
      keys           = "<tab><tab>",
      pause_after_ms = 5000
    },
    // Enter the IP address
    {
      keys           = nightlight_instance.nutanix.primary_ip_address,
      pause_after_ms = 5000
    },
    // Tab to controller vm IP address
    {
      keys           = "<tab>",
      pause_after_ms = 5000
    },
    // Enter the controller vm IP address
    {
      keys           = "192.168.128.201",
      pause_after_ms = 5000
    },
    // Tab to subnet mask
    {
      keys           = "<tab>",
      pause_after_ms = 5000
    },
    // Enter the subnet mask
    {
      keys           = "255.255.255.0",
      pause_after_ms = 5000
    },
    // Tab to gateway
    {
      keys           = "<tab>",
      pause_after_ms = 5000
    },
    // Enter the gateway
    {
      keys           = "192.168.128.1",
      pause_after_ms = 5000
    },
    {
      keys           = "<tab>",
      pause_after_ms = 5000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 20000
    },
    {
      keys           = "<pgdn>",
      pause_after_ms = 5000,
      count          = 30
    },
    {
      keys           = "<tab>",
      pause_after_ms = 5000
    },
    {
      keys           = "<space>",
      pause_after_ms = 5000
    },
    {
      keys           = "<tab>",
      pause_after_ms = 5000
    },
    {
      keys           = "<tab>",
      pause_after_ms = 5000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 1000000
    },
    {
      keys           = "y",
      pause_after_ms = 5000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 1200000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 5000
    },
    {
      keys           = "root",
      pause_after_ms = 5000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 5000
    },
    {
      keys           = "nutanix/4u",
      pause_after_ms = 5000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 5000
    },
    {
      keys           = "ssh nutanix@192.168.128.201",
      pause_after_ms = 5000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 5000
    },
    {
      keys           = "yes",
      pause_after_ms = 5000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 5000
    },
    {
      keys           = "nutanix/4u",
      pause_after_ms = 5000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 5000
    },
    {
      keys           = "cluster -s 192.168.128.201 --redundancy_factor=1 create",
      pause_after_ms = 5000
    },
    {
      keys           = "<enter>",
      pause_after_ms = 5000
    },
  ]
}
