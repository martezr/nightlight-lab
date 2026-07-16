# Look up an image by name and deploy an instance from it.
data "nightlight_image" "ubuntu24" {
  name = "Ubuntu 24.04 LTS"
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

data "nightlight_image" "vme" {
  name = local.vme_images[local.vme_version].iso
}

locals {
  vme_version = "9.0.0"
  vme_images = {
    "8.1.2" = {
      iso   = "HPE_VM_Essentials_SW_image_v8.1.2_S5Q83-11075.iso"
      qcow2 = "hpe-vm-essentials-8.1.2-1.qcow2.gz"
    }
    "9.0.0" = {
      iso   = "HPE_VM_Essentials_SW_image_v9.0.0_S5Q83-11075.iso"
      qcow2 = "hpe-vm-essentials-9.0.0-1.qcow2.gz"
    }
  }
}


resource "nightlight_instance" "vme" {
  name         = "vme01"
  description  = "HPE Morpheus VM Essentials"
  cpu_cores    = 8
  cpu_sockets  = 2
  memory_mb    = 49152
  datastore_id = "defaultdatastore"
  user_data = templatefile("${path.module}/userdata.sh", {
    hostname = "vme01"
    fqdn     = "vme01.rmslab.net"
  })
  site_id       = data.nightlight_site.example.id
  instance_type = "virtualmachine"
  cdroms = [
    {
      index_number = 0
      boot_order   = 2
      connected    = true
      path         = data.nightlight_image.vme.path
    }
  ]

  storage_disks = [
    {
      index_number  = 0
      boot_order    = 1
      size_gb       = 250
      bus_type      = "virtio"
      datastore_id  = "defaultdatastore"
      existing_path = data.nightlight_image.ubuntu24.path
    }
  ]

  network_interfaces = [
    {
      index_number = 0
      boot_order   = 3
      bridge_name  = data.nightlight_site.example.bridges[0]
      subnet_id    = data.nightlight_subnet.management.id
      model        = "e1000"
      connected    = true
    }
    # {
    #   index_number = 1
    #   boot_order   = 5
    #   bridge_name  = data.nightlight_site.example.bridges[0]
    #   subnet_id    = data.nightlight_subnet.compute.id
    #   model        = "virtio"
    #   connected    = true
    # }
  ]
  # Define the connection parameters for the provisioner
  connection {
    type     = "ssh"
    user     = "mreed"
    password = "Password123#"
    host     = self.primary_ip_address
  }

  # Step 1: Upload the manifest.yaml file to the remote instance
  provisioner "file" {
    content = templatefile("${path.module}/bootstrap.sh", {
      hostname   = "vme01"
      fqdn       = "vme01.rmslab.net"
      ip_address = self.primary_ip_address
    })
    destination = "/home/mreed/bootstrap.sh"
  }

  # Step 2: Run shell commands over the established SSH tunnel
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo mkdir /mnt/demo && sudo mount /dev/sr0 /mnt/demo && sudo apt install -y -f /mnt/demo/hpe-vm*.deb",
      "sudo chmod +x /home/mreed/bootstrap.sh && sudo /home/mreed/bootstrap.sh ${local.vme_images[local.vme_version].qcow2}"
    ]
  }
}
