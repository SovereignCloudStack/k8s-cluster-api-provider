output "mgmtcluster_address" {
  value     = openstack_networking_floatingip_v2.mgmtcluster_floatingip.address
  sensitive = true
}

output "private_key" {
  value     = openstack_compute_keypair_v2.keypair.private_key
  sensitive = true
}

resource "local_file" "id_rsa" {
  filename          = ".deploy.id_rsa.${var.cloud_provider}"
  file_permission   = "0600"
  sensitive_content = openstack_compute_keypair_v2.keypair.private_key
}

resource "local_file" "MGMTCLUSTER_ADDRESS" {
  filename        = ".deploy.MGMTCLUSTER_ADDRESS.${var.cloud_provider}"
  file_permission = "0644"
  content         = "MGMTCLUSTER_ADDRESS=${openstack_networking_floatingip_v2.mgmtcluster_floatingip.address}\n"
}
