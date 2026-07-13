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

output "ip_addresses" {
  value = nightlight_instance.openstack.guest_ip_addresses
}

resource "nightlight_instance" "openstack" {
  name         = "openstack01"
  cpu_cores    = 8
  cpu_sockets  = 2
  memory_mb    = 32768
  datastore_id = "defaultdatastore"
  user_data = templatefile("${path.module}/userdata.sh", {
    hostname = "openstack01"
    fqdn     = "openstack01.rmslab.net"
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
    host     = nightlight_instance.openstack.guest_ip_addresses[0]
  }

  # Step 1: Upload the manifest.yaml file to the remote instance
  provisioner "file" {
    source      = "${path.module}/manifest.yaml"
    destination = "/home/mreed/manifest.yaml"
  }

  # Step 2: Run shell commands over the established SSH tunnel
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "for i in 1 2 3 4 5; do sudo snap install openstack --channel 2024.1/stable && break; echo \"Snap install attempt $i failed, retrying in 30s...\"; sleep 30; done",
      "/snap/bin/sunbeam prepare-node-script --bootstrap | bash -x",
      "sg snap_daemon -c '/snap/bin/sunbeam cluster bootstrap --manifest /home/mreed/manifest.yaml 2>&1 || (sudo journalctl -u snap.openstack.* --no-pager -n 100; exit 1)'"
    ]
  }

}
