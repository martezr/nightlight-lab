resource "hpe_morpheus_group" "rmslab" {
  name     = "rmslab"
  code     = "rmslab"
  location = "lab"
  depends_on = [ nightlight_instance.vme ]
}

resource "hpe_morpheus_cloud" "example" {
  name       = "vmecloud"
  tenant_id  = 1
  group_id   = hpe_morpheus_group.rmslab.id
  enabled    = true
  location   = "somewhere"
  visibility = "public"

  agent_install_mode       = "ssh"
  appliance_url            = "https://${local.vmemanager}"
  auto_recover_power_state = true
  import_existing_vms      = "off"
  costing_mode             = "costing"
  guidance_mode            = "off"
  security_mode            = "off"
  keyboard_layout          = "us"

  config_hvm = {
    certificate_provider          = "internal"
    enable_network_type_selection = false
  }
  depends_on = [ nightlight_instance.vme ]
}

data "hpe_morpheus_cluster_type" "hvmcluster" {
  name = "HVM"
  depends_on = [ nightlight_instance.vme ]
}

resource "hpe_morpheus_cluster" "example_hvm" {
  name        = "vmecluster"
  description = "A test HVM cluster"
  cloud_id    = hpe_morpheus_cloud.example.id
  group_id    = hpe_morpheus_group.rmslab.id
  layout_id   = 266

  config_hvm = {
    create_user       = false
    dynamic_placement = false
    cpu_arch          = "x86_64"
    cpu_model         = "host-model"
    power_policy      = "performance"
  }

  server = {
    service_plan_id          = 2
    ssh_port                 = 22
    ssh_username             = "mreed"
    ssh_password_wo          = "Password123#"
    management_net_interface = "ens1"

    ssh_hosts = [
      {
        name = "vme01"
        ip   = nightlight_instance.vme.primary_ip_address
      }
    ]
    visibility = "private"
  }
  depends_on = [ nightlight_instance.vme ]
}