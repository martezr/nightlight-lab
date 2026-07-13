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

output "ip_addresses" {
  value = nightlight_instance.salt.guest_ip_addresses
}

resource "nightlight_instance" "salt" {
  name         = "salt01"
  cpu_cores    = 4
  cpu_sockets  = 2
  memory_mb    = 4096
  datastore_id = "defaultdatastore"
  user_data = templatefile("${path.module}/userdata.sh", {
    hostname = "salt01"
    fqdn     = "salt01.rmslab.net"
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
    }
  ]

  network_interfaces = [
    {
      index_number = 0
      boot_order   = 2
      bridge_name  = data.nightlight_site.example.bridges[0]
      subnet_id    = data.nightlight_subnet.management.id
      model        = "virtio"
      connected    = true
    }
  ]
  # Define the connection parameters for the provisioner
  connection {
    type     = "ssh"
    user     = "mreed"
    password = "Password123#"
    host     = nightlight_instance.salt.guest_ip_addresses[0]
  }

  # Step 1: Run shell commands over the established SSH tunnel
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get remove -y needrestart",
      "sudo apt install -y curl wget gnupg lsb-release ca-certificates python3-pygit2 libgit2-26 python3-git",
      "wget https://raw.githubusercontent.com/saltstack/salt-bootstrap/refs/heads/develop/bootstrap-salt.sh",
      "sudo chmod +x bootstrap-salt.sh",
      "sudo env DEBIAN_FRONTEND=noninteractive ./bootstrap-salt.sh -P -M",
      "sudo systemctl enable salt-master && sudo systemctl start salt-master",
    ]
  }

  # Step 1: Upload the manifest.yaml file to the remote instance
  provisioner "file" {
    source = "${path.module}/saltbootstrap.sh"
    destination = "/home/mreed/saltbootstrap.sh"
  }

  # Step 2: Run shell commands over the established SSH tunnel
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo chmod +x /home/mreed/saltbootstrap.sh",
      "sudo /home/mreed/saltbootstrap.sh"
    ]
  }
}