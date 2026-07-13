resource "openstack_identity_project_v3" "rmsproject" {
  name        = "rmsdemo"
  description = "RiverMeadow demo project"
  depends_on  = [nightlight_instance.openstackkolla]
}

resource "openstack_identity_user_v3" "user_1" {
  default_project_id                    = openstack_identity_project_v3.rmsproject.id
  name                                  = "rmsmigration"
  description                           = "A user"
  password                              = "Password123#"
  ignore_change_password_upon_first_use = true
  multi_factor_auth_enabled             = false
  extra = {
    email = "rmsmigration@rmslab.net"
  }
  depends_on = [nightlight_instance.openstackkolla]
}

data "openstack_identity_role_v3" "admin" {
  name       = "admin"
  depends_on = [nightlight_instance.openstackkolla]
}

resource "openstack_identity_role_assignment_v3" "role_assignment_1" {
  user_id    = openstack_identity_user_v3.user_1.id
  project_id = openstack_identity_project_v3.rmsproject.id
  role_id    = data.openstack_identity_role_v3.admin.id
  depends_on = [nightlight_instance.openstackkolla]
}


// Assign the "admin" role to the global admin in the rmsdemo project
data "openstack_identity_user_v3" "global_admin" {
  name = "admin"
  depends_on = [nightlight_instance.openstackkolla]
}

resource "openstack_identity_role_assignment_v3" "global_role_assignment" {
  user_id    = data.openstack_identity_user_v3.global_admin.id
  project_id = openstack_identity_project_v3.rmsproject.id
  role_id    = data.openstack_identity_role_v3.admin.id
  depends_on = [nightlight_instance.openstackkolla]
}

// Configure external network and router for the rmsdemo project
resource "openstack_networking_network_v2" "external_network" {
  name        = "external"
  description = "External network for the rmsdemo project"
  external    = true
  tenant_id   = openstack_identity_project_v3.rmsproject.id
  segments {
    physical_network = "physnet1"
    network_type     = "flat"
  }
  depends_on = [nightlight_instance.openstackkolla]
}

resource "openstack_networking_subnet_v2" "external_subnet" {
  name            = "external_subnet"
  network_id      = openstack_networking_network_v2.external_network.id
  cidr            = "192.168.129.0/24"
  ip_version      = 4
  tenant_id       = openstack_identity_project_v3.rmsproject.id
  gateway_ip      = "192.168.129.1"
  dns_nameservers = ["4.2.2.2", "8.8.8.8"]
  enable_dhcp     = false
  depends_on      = [nightlight_instance.openstackkolla]
}

// Create an internal network and subnet for the rmsdemo project
resource "openstack_networking_network_v2" "internal_network" {
  name       = "internal"
  tenant_id  = openstack_identity_project_v3.rmsproject.id
  depends_on = [nightlight_instance.openstackkolla]
}

resource "openstack_networking_subnet_v2" "internal_subnet" {
  name            = "internal_subnet"
  network_id      = openstack_networking_network_v2.internal_network.id
  cidr            = "10.0.120.0/24"
  ip_version      = 4
  tenant_id       = openstack_identity_project_v3.rmsproject.id
  gateway_ip      = "10.0.120.1"
  dns_nameservers = ["4.2.2.2", "8.8.8.8"]
  enable_dhcp     = true
  allocation_pool {
    start = "10.0.120.50"
    end   = "10.0.120.100"
  }
  depends_on = [nightlight_instance.openstackkolla]
}

// Create a router to connect the internal network to the external network
resource "openstack_networking_router_v2" "router" {
  name                = "rmsdemo_router"
  tenant_id           = openstack_identity_project_v3.rmsproject.id
  external_network_id = openstack_networking_network_v2.external_network.id
  enable_snat         = true
  depends_on          = [nightlight_instance.openstackkolla]
}

resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.internal_subnet.id
}

// Deploy cirros image to the rmsdemo project
resource "openstack_images_image_v2" "cirros_image" {
  name             = "cirros"
  disk_format      = "qcow2"
  container_format = "bare"
  visibility       = "public"
  image_source_url = "https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img"
  web_download     = true
  depends_on       = [nightlight_instance.openstackkolla]
}

// Create a flavor for the cirros instance
resource "openstack_compute_flavor_v2" "cirros_flavor" {
  name       = "m1.tiny"
  ram        = 1024
  vcpus      = 1
  disk       = 5
  is_public  = true
  depends_on = [nightlight_instance.openstackkolla]
}

resource "openstack_networking_secgroup_v2" "rms_secgroup" {
  name        = "rms_secgroup"
  description = "My neutron security group"
  tenant_id   = openstack_identity_project_v3.rmsproject.id
  depends_on  = [nightlight_instance.openstackkolla]
}

# resource "openstack_networking_secgroup_rule_v2" "egress_secgroup_rule_v4" {
#   direction         = "egress"
#   ethertype         = "IPv4"
#   port_range_min    = 0
#   port_range_max    = 0
#   remote_ip_prefix  = "0.0.0.0/0"
#   security_group_id = openstack_networking_secgroup_v2.rms_secgroup.id
#   tenant_id         = openstack_identity_project_v3.rmsproject.id
# }

resource "openstack_networking_secgroup_rule_v2" "ingress_secgroup_rule_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  port_range_min    = 0
  port_range_max    = 0
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.rms_secgroup.id
  tenant_id         = openstack_identity_project_v3.rmsproject.id
}

resource "openstack_compute_flavor_v2" "m1-small" {
  name       = "m1.small"
  ram        = 2048
  vcpus      = 2
  disk       = 10
  is_public  = true
  depends_on = [nightlight_instance.openstackkolla]
}

resource "openstack_compute_flavor_v2" "m1-medium" {
  name       = "m1.medium"
  ram        = 4096
  vcpus      = 2
  disk       = 40
  is_public  = true
  depends_on = [nightlight_instance.openstackkolla]
}

resource "openstack_compute_flavor_v2" "m1-large" {
  name       = "m1.large"
  ram        = 8192
  vcpus      = 4
  disk       = 80
  is_public  = true
  depends_on = [nightlight_instance.openstackkolla]
}

resource "openstack_compute_flavor_v2" "m1-xlarge" {
  name       = "m1.xlarge"
  ram        = 16384
  vcpus      = 8
  disk       = 160
  is_public  = true
  depends_on = [nightlight_instance.openstackkolla]
}