# - ssh keypair -
resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.prefix}-keypair"
}

# - application credential -
resource "openstack_identity_application_credential_v3" "appcred" {
  name        = "${var.prefix}-appcred"
  description = "Credential for the ${var.prefix} management"
}

# - management cluster -
resource "openstack_networking_floatingip_v2" "mgmtcluster_floatingip" {
  pool       = var.external
  depends_on = [openstack_networking_router_interface_v2.router_interface]
}

resource "openstack_networking_port_v2" "mgmtcluster_port" {
  network_id = openstack_networking_network_v2.network_mgmt.id
  name       = "${var.prefix}-port"
  security_group_ids = [
    openstack_compute_secgroup_v2.security_group_mgmt.id,
  ]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet_mgmt.id
  }
}

resource "openstack_networking_floatingip_associate_v2" "mgmtcluster_floatingip_association" {
  floating_ip = openstack_networking_floatingip_v2.mgmtcluster_floatingip.address
  port_id     = openstack_networking_port_v2.mgmtcluster_port.id
}

locals {
  clouds = yamldecode(file("mycloud.${var.cloud_provider}.yaml"))
}

resource "openstack_compute_instance_v2" "mgmtcluster_server" {
  name              = "${var.prefix}-mgmtcluster"
  image_name        = var.image
  flavor_name       = var.kind_flavor
  availability_zone = var.availability_zone
  key_pair          = openstack_compute_keypair_v2.keypair.name

  network { port = openstack_networking_port_v2.mgmtcluster_port.id }

  user_data = <<-EOF

#cloud-config
final_message: "The system is finally up, after $UPTIME seconds"
package_update: true
package_upgrade: true
write_files:
  - content: |
      {
        "mtu": ${var.kind_mtu}
      }
    owner: root:root
    path: /tmp/daemon.json
    permissions: '0644'
runcmd:
  - echo nf_conntrack > /etc/modules-load.d/90-nf_conntrack.conf
  - modprobe nf_conntrack
  - echo net.netfilter.nf_conntrack_max=131072 > /etc/sysctl.d/90-conntrack_max.conf
  - sysctl -w -p /etc/sysctl.d/90-conntrack_max.conf
  - mkdir /etc/docker
  - /home/${var.ssh_username}/bin/get_mtu.sh
  - mv /tmp/daemon.json /etc/docker/daemon.json
  - groupadd docker
  - usermod -aG docker ${var.ssh_username}
  - apt -y install docker.io yamllint qemu-utils
EOF

  connection {
    host        = openstack_networking_floatingip_v2.mgmtcluster_floatingip.address
    private_key = openstack_compute_keypair_v2.keypair.private_key
    user        = var.ssh_username
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.ssh_username}/.config/openstack",
      "mkdir -p /home/${var.ssh_username}/cluster-defaults",
    ]
  }

  provisioner "file" {
    content     = openstack_compute_keypair_v2.keypair.private_key
    destination = "/home/${var.ssh_username}/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "files/bin/bootstrap.sh"
    destination = "/home/${var.ssh_username}/bootstrap.sh"
  }

  provisioner "file" {
    source      = "files/bin/wait.sh"
    destination = "/home/${var.ssh_username}/wait.sh"
  }

  provisioner "file" {
    content     = templatefile("files/template/capi-settings.tmpl", { clusterapi_version = var.clusterapi_version, capi_openstack_version = var.capi_openstack_version, calico_version = var.calico_version, prefix = var.prefix })
    destination = "/home/${var.ssh_username}/.capi-settings"
  }

  provisioner "file" {
    content     = templatefile("files/template/clusterctl.yaml.tmpl", { kubernetes_version = var.kubernetes_version, availability_zone = var.availability_zone, external = var.external, image = var.image, controller_flavor = var.controller_flavor, worker_flavor = var.worker_flavor, cloud_provider = var.cloud_provider, worker_count = var.worker_count, controller_count = var.controller_count, kind_mtu = var.kind_mtu, prefix = var.prefix, deploy_nginx_ingress = var.deploy_nginx_ingress, deploy_cert_manager = var.deploy_cert_manager, deploy_flux = var.deploy_flux, deploy_metrics = var.deploy_metrics, deploy_k8s_openstack_git = var.deploy_k8s_openstack_git, deploy_k8s_cindercsi_git = var.deploy_k8s_cindercsi_git, use_cilium = var.use_cilium, node_cidr = var.node_cidr, dns_nameservers = var.dns_nameservers, anti_affinity = var.anti_affinity, kube_image_raw = var.kube_image_raw, image_registration_extra_flags = var.image_registration_extra_flags, etcd_prio_boost = var.etcd_prio_boost, etcd_unsafe_fs = var.etcd_unsafe_fs })
    destination = "/home/${var.ssh_username}/cluster-defaults/clusterctl.yaml"
  }

  provisioner "file" {
    content     = templatefile("files/template/clouds.yaml.tmpl", { cloud_provider = var.cloud_provider, clouds = local.clouds, appcredid = openstack_identity_application_credential_v3.appcred.id, appcredsecret = openstack_identity_application_credential_v3.appcred.secret })
    destination = "/home/${var.ssh_username}/.config/openstack/clouds.yaml"
  }

  provisioner "file" {
    content     = templatefile("files/template/cloud.conf.tmpl", { cloud_provider = var.cloud_provider, clouds = local.clouds, appcredid = openstack_identity_application_credential_v3.appcred.id, appcredsecret = openstack_identity_application_credential_v3.appcred.secret })
    destination = "/home/${var.ssh_username}/cluster-defaults/cloud.conf"
  }

  provisioner "file" {
    source      = "files/template/cluster-template.yaml"
    destination = "/home/${var.ssh_username}/cluster-defaults/cluster-template.yaml"
  }

  provisioner "file" {
    source      = "files/fix-keystoneauth-plugins-unversioned.diff"
    destination = "/home/${var.ssh_username}/fix-keystoneauth-plugins-unversioned.diff"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0600 /home/${var.ssh_username}/.ssh/id_rsa /home/${var.ssh_username}/cluster-defaults/clusterctl.yaml /home/${var.ssh_username}/cluster-defaults/cloud.conf /home/${var.ssh_username}/.config/openstack/clouds.yaml",
      "chmod 0755 /home/${var.ssh_username}/*.sh"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "bash /home/${var.ssh_username}/wait.sh"
    ]
  }

  provisioner "file" {
    source      = "extension"
    destination = "/home/${var.ssh_username}/"
  }

  provisioner "remote-exec" {
    inline = [
      "bash /home/${var.ssh_username}/bootstrap.sh feat/repo-on-mgmtcluster"
    ]
  }
}
