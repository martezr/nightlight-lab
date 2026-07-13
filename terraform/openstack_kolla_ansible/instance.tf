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

resource "nightlight_instance" "openstackkolla" {
  name         = "openstackkolla01"
  description  = "OpenStack Kolla Ansible Deployment"
  cpu_cores    = 8
  cpu_sockets  = 2
  memory_mb    = 32768
  datastore_id = "defaultdatastore"
  user_data = templatefile("${path.module}/userdata.sh", {
    hostname = "openstackkolla01"
    fqdn     = "openstackkolla01.rmslab.net"
  })
  site_id       = data.nightlight_site.example.id
  instance_type = "virtualmachine"
  storage_disks = [
    {
      index_number  = 0
      boot_order    = 1
      size_gb       = 200
      bus_type      = "virtio"
      datastore_id  = "defaultdatastore"
      existing_path = data.nightlight_image.ubuntu24.path
    },
    {
      index_number = 1
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
    },
    {
      index_number = 1
      boot_order   = 4
      bridge_name  = data.nightlight_site.example.bridges[0]
      subnet_id    = data.nightlight_subnet.compute.id
      model        = "virtio"
      connected    = true
    }
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
    content = templatefile("${path.module}/openstackbootstrap.sh", {
      hostname   = "openstackkolla01"
      fqdn       = "openstackkolla01.rmslab.net"
      ip_address = self.primary_ip_address
    })
    destination = "/home/mreed/openstackbootstrap.sh"
  }

  # Step 2: Run shell commands over the established SSH tunnel
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo chmod +x /home/mreed/openstackbootstrap.sh",
      "sudo /home/mreed/openstackbootstrap.sh"
    ]
  }
}
