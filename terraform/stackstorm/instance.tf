# Look up an image by name and deploy an instance from it.

data "nightlight_image" "ubuntu24" {
  name = "Ubuntu 22.04 LTS"
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

output "ip_addresses" {
  value = nightlight_instance.stackstorm.guest_ip_addresses
}

resource "nightlight_instance" "stackstorm" {
  name         = "stackstorm01"
  cpu_cores    = 4
  cpu_sockets  = 2
  memory_mb    = 4096
  datastore_id = "defaultdatastore"
  user_data = templatefile("${path.module}/userdata.sh", {
    hostname = "stackstorm01"
    fqdn     = "stackstorm01.rmslab.net"
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
    host     = nightlight_instance.stackstorm.guest_ip_addresses[0]
  }

  # Step 1: Run shell commands over the established SSH tunnel
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get remove -y needrestart",
      "sudo wget -O /tmp/st2bootstrap-deb.sh https://raw.githubusercontent.com/StackStorm/st2-packages/refs/heads/v3.9/scripts/st2bootstrap-deb.sh",
      "sudo chmod +x /tmp/st2bootstrap-deb.sh",
      "sudo env DEBIAN_FRONTEND=noninteractive /tmp/st2bootstrap-deb.sh --version=3.9.0 --user=st2admin --password=Ch@ngeMe",
      "sleep 3m && /usr/bin/st2 login st2admin -p 'Ch@ngeMe' && /usr/bin/st2 run packs.install packs=terraform && /usr/bin/st2 run packs.install packs=git && /usr/bin/st2 run packs.install packs=activedirectory && /usr/bin/st2 run packs.install packs=hyperv && /usr/bin/st2 run packs.install packs=salt",
      "curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg",
      "echo 'deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com jammy main' | sudo tee /etc/apt/sources.list.d/hashicorp.list",
      "sudo apt-get update && sudo apt-get install -y terraform",
    ]
  }

  # Step 1: Upload the manifest.yaml file to the remote instance
  provisioner "file" {
    source = "${path.module}/install.sh"
    destination = "/home/mreed/openstackbootstrap.sh"
  }

  # Step 2: Run shell commands over the established SSH tunnel
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo chmod +x /home/mreed/install.sh",
      "sudo /home/mreed/install.sh"
    ]
  }
}