# generic security group allow ssh connection 
# used for cluster-api-nodes
resource "openstack_compute_secgroup_v2" "security_group_ssh" {
  name        = "allow-ssh"
  description = "security group for ssh 22/tcp (managed by terraform)"

  rule {
    cidr        = "0.0.0.0/0"
    ip_protocol = "tcp"
    from_port   = 22
    to_port     = 22
  }
}

# generic security group allow icmp connection
# used for cluster-api-nodes
resource "openstack_compute_secgroup_v2" "security_group_icmp" {
  name        = "allow-icmp"
  description = "security group for ICMP"

  rule {
    cidr        = "0.0.0.0/0"
    ip_protocol = "icmp"
    from_port   = -1
    to_port     = -1
  }
}
# security group allow ssh/icmp connection to mgmt cluster/host
#
resource "openstack_compute_secgroup_v2" "security_group_mgmt" {
  name        = "${var.prefix}-mgmt"
  description = "security group for mgmtcluster (managed by terraform)"

  rule {
    cidr        = "0.0.0.0/0"
    ip_protocol = "tcp"
    from_port   = 22
    to_port     = 22
  }

  rule {
    cidr        = "0.0.0.0/0"
    ip_protocol = "icmp"
    from_port   = -1
    to_port     = -1
  }
}

resource "openstack_networking_network_v2" "network_mgmt" {
  name = "${var.prefix}-net"
  #  availability_zone_hints = [var.availability_zone]
  #  admin_state_up          = "true"
}

resource "openstack_networking_subnet_v2" "subnet_mgmt" {
  name       = "${var.prefix}-subnet"
  network_id = openstack_networking_network_v2.network_mgmt.id
  ip_version = 4
  cidr       = "10.0.0.0/24"

  allocation_pool {
    start = "10.0.0.11"
    end   = "10.0.0.254"
  }
}

data "openstack_networking_network_v2" "external" {
  name = var.external
}

resource "openstack_networking_router_v2" "router_mgmt" {
  name                    = "${var.prefix}-rtr"
  description             = "router for mgmtcluster (managed by terraform)"
  external_network_id     = data.openstack_networking_network_v2.external.id
  availability_zone_hints = [var.availability_zone]
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router_mgmt.id
  subnet_id = openstack_networking_subnet_v2.subnet_mgmt.id
}
