# - ssh keypair -
resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.prefix}-keypair"
}

# - application credential -
resource "openstack_identity_application_credential_v3" "appcred" {
  name         = "${var.prefix}-appcred"
  description  = "Credential for the ${var.prefix} management"
  unrestricted = true
}

data "openstack_networking_network_v2" "extnet" {
  external = true
}

# - management cluster -
resource "openstack_networking_floatingip_v2" "mgmtcluster_floatingip" {
  pool        = var.external != "" ? var.external : data.openstack_networking_network_v2.extnet.name
  depends_on  = [openstack_networking_router_interface_v2.router_interface]
  description = "Floating IP for the ${var.prefix} management cluster node"
  tags = [
    "${var.prefix}-mgmtcluster", "k8s-cluster-api-mgmtcluster"
  ]
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

data "openstack_images_image_ids_v2" "images" {
  name = var.image
  sort = "updated_at:desc"
}

resource "openstack_blockstorage_volume_v3" "mgmtcluster_volume" {
  size        = 30
  name        = "${var.prefix}-mgmtcluster"
  image_id    = data.openstack_images_image_ids_v2.images.ids[0]
  description = "Volume for the ${var.prefix} management cluster node"
}

resource "openstack_compute_instance_v2" "mgmtcluster_server" {
  name              = "${var.prefix}-mgmtcluster"
  flavor_name       = var.kind_flavor
  availability_zone = var.availability_zone
  key_pair          = openstack_compute_keypair_v2.keypair.name
  # image_name      = var.image

  network { port = openstack_networking_port_v2.mgmtcluster_port.id }
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.mgmtcluster_volume.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  lifecycle {
    # Prevents Terraform from trying to destroy the instance when it was created before update with labeling its volume
    ignore_changes = [block_device]
  }

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
  - content: |
      $nrconf{kernelhints} = -1;
      $nrconf{restart} = 'a';
    owner: root:root
    path: /etc/needrestart/conf.d/needrestart.conf
    permissions: '0644'
runcmd:
  # Note: Needrestart is part of the `apt-get upgrade` process from Ubuntu 22.04. By default, it is set to an
  #   "interactive" mode which causes the interruption of scripts. The interactive mode is applied when the new kernel
  #   version is available after the upgrade process and when upgraded services need to restart. A custom configuration
  #   file overrides mentioned settings and ensures that kernel hints are printed only to stderr and services are
  #   restarted automatically if needed.
  - echo nf_conntrack > /etc/modules-load.d/90-nf_conntrack.conf
  - modprobe nf_conntrack
  - echo net.netfilter.nf_conntrack_max=131072 > /etc/sysctl.d/90-conntrack_max.conf
  - sysctl -w -p /etc/sysctl.d/90-conntrack_max.conf
  - mkdir /etc/docker
  - /tmp/get_mtu.sh
  - mv /tmp/daemon.json /etc/docker/daemon.json
  - groupadd docker
  - usermod -aG docker ${var.ssh_username}
  - apt-get -y install --no-install-recommends --no-install-suggests docker.io yamllint qemu-utils git
EOF

}

resource "terraform_data" "cacert" {
  depends_on = [
    openstack_compute_instance_v2.mgmtcluster_server
  ]

  count = contains(keys(local.clouds), "cacert") ? 1 : 0

  triggers_replace = [
    openstack_networking_floatingip_v2.mgmtcluster_floatingip.address,
    file(local.clouds["cacert"])
  ]

  connection {
    host        = openstack_networking_floatingip_v2.mgmtcluster_floatingip.address
    private_key = openstack_compute_keypair_v2.keypair.private_key
    user        = var.ssh_username
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.ssh_username}/cluster-defaults"
    ]
  }

  provisioner "file" {
    source      = local.clouds["cacert"]
    destination = "/home/${var.ssh_username}/cluster-defaults/${var.cloud_provider}-cacert"
  }
}

resource "terraform_data" "mgmtcluster_containerd_registry_host_files" {
  depends_on = [
    openstack_compute_instance_v2.mgmtcluster_server
  ]

  for_each = toset(var.containerd_registry_files["hosts"])

  triggers_replace = [
    openstack_networking_floatingip_v2.mgmtcluster_floatingip.address,
    file(each.key)
  ]

  connection {
    host        = openstack_networking_floatingip_v2.mgmtcluster_floatingip.address
    private_key = openstack_compute_keypair_v2.keypair.private_key
    user        = var.ssh_username
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.ssh_username}/cluster-defaults/containerd/hosts"
    ]
  }

  provisioner "file" {
    source      = each.key
    destination = "/home/${var.ssh_username}/cluster-defaults/containerd/hosts/${basename(each.key)}"
  }
}

resource "terraform_data" "mgmtcluster_containerd_registry_cert_files" {
  depends_on = [
    openstack_compute_instance_v2.mgmtcluster_server
  ]

  for_each = toset(var.containerd_registry_files["certs"])

  triggers_replace = [
    openstack_networking_floatingip_v2.mgmtcluster_floatingip.address,
    file(each.key)
  ]

  connection {
    host        = openstack_networking_floatingip_v2.mgmtcluster_floatingip.address
    private_key = openstack_compute_keypair_v2.keypair.private_key
    user        = var.ssh_username
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.ssh_username}/cluster-defaults/containerd/certs"
    ]
  }

  provisioner "file" {
    source      = each.key
    destination = "/home/${var.ssh_username}/cluster-defaults/containerd/certs/${basename(each.key)}"
  }
}

resource "terraform_data" "mgmtcluster_bootstrap_files" {
  depends_on = [
    openstack_compute_instance_v2.mgmtcluster_server,
    terraform_data.mgmtcluster_containerd_registry_host_files,
    terraform_data.mgmtcluster_containerd_registry_cert_files
  ]

  triggers_replace = [
    openstack_networking_floatingip_v2.mgmtcluster_floatingip.address
  ]

  connection {
    host        = openstack_networking_floatingip_v2.mgmtcluster_floatingip.address
    private_key = openstack_compute_keypair_v2.keypair.private_key
    user        = var.ssh_username
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.ssh_username}/.config/openstack"
    ]
  }

  provisioner "file" {
    content     = openstack_compute_keypair_v2.keypair.private_key
    destination = "/home/${var.ssh_username}/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "files/bin/get_k8s_git.sh"
    destination = "/tmp/get_k8s_git.sh"
  }

  provisioner "file" {
    source      = "files/bin/wait.sh"
    destination = "/tmp/wait.sh"
  }

  provisioner "file" {
    source      = "files/bin/get_mtu.sh"
    destination = "/tmp/get_mtu.sh"
  }

  provisioner "file" {
    content = templatefile("files/template/capi-settings.tmpl", {
      cilium_binaries        = var.cilium_binaries,
      capi_openstack_version = var.capi_openstack_version,
      clusterapi_version     = var.clusterapi_version,
      prefix                 = var.prefix,
      testcluster_name       = var.testcluster_name
    })
    destination = "/home/${var.ssh_username}/.capi-settings"
  }

  provisioner "file" {
    content = templatefile("files/template/clusterctl.yaml.tmpl", {
      anti_affinity                  = var.anti_affinity,
      availability_zone              = var.availability_zone,
      capo_instance_create_timeout   = var.capo_instance_create_timeout
      cloud_provider                 = var.cloud_provider,
      controller_count               = var.controller_count,
      controller_flavor              = var.controller_flavor,
      deploy_cert_manager            = var.deploy_cert_manager,
      deploy_cindercsi               = var.deploy_cindercsi,
      deploy_flux                    = var.deploy_flux,
      deploy_metrics                 = var.deploy_metrics,
      deploy_nginx_ingress           = var.deploy_nginx_ingress,
      deploy_gateway_api             = var.deploy_gateway_api,
      deploy_occm                    = var.deploy_occm,
      dns_nameservers                = var.dns_nameservers,
      etcd_unsafe_fs                 = var.etcd_unsafe_fs,
      external                       = var.external != "" ? var.external : data.openstack_networking_network_v2.extnet.name,
      image_registration_extra_flags = var.image_registration_extra_flags,
      kube_image_raw                 = var.kube_image_raw,
      kubernetes_version             = var.kubernetes_version,
      node_cidr                      = var.node_cidr,
      pod_cidr                       = var.pod_cidr,
      service_cidr                   = var.service_cidr,
      prefix                         = var.prefix,
      restrict_kubeapi               = var.restrict_kubeapi
      use_cilium                     = var.use_cilium,
      calico_version                 = var.calico_version,
      use_ovn_lb_provider            = var.use_ovn_lb_provider,
      worker_count                   = var.worker_count,
      worker_flavor                  = var.worker_flavor,
    })
    destination = "/home/${var.ssh_username}/cluster-defaults/clusterctl.yaml"
  }

  provisioner "file" {
    content = templatefile("files/template/clouds.yaml.tmpl", {
      appcredid      = openstack_identity_application_credential_v3.appcred.id,
      appcredsecret  = openstack_identity_application_credential_v3.appcred.secret,
      cloud_provider = var.cloud_provider,
      clouds         = local.clouds,
      cacert         = contains(keys(local.clouds), "cacert") ? "/home/${var.ssh_username}/cluster-defaults/${var.cloud_provider}-cacert" : "null"
    })
    destination = "/home/${var.ssh_username}/.config/openstack/clouds.yaml"
  }

  provisioner "file" {
    content = templatefile("files/template/cloud.conf.tmpl", {
      clouds        = local.clouds,
      appcredid     = openstack_identity_application_credential_v3.appcred.id,
      appcredsecret = openstack_identity_application_credential_v3.appcred.secret
    })
    destination = "/home/${var.ssh_username}/cluster-defaults/cloud.conf"
  }

  provisioner "file" {
    content = templatefile("files/template/harbor-settings.tmpl", {
      deploy_harbor = var.deploy_harbor,
      harbor_config = var.harbor_config
    })
    destination = "/home/${var.ssh_username}/cluster-defaults/harbor-settings"
  }

  provisioner "file" {
    source      = "files/template/cluster-template.yaml"
    destination = "/home/${var.ssh_username}/cluster-defaults/cluster-template.yaml"
  }

  provisioner "file" {
    source      = "files/fix-keystoneauth-plugins-unversioned.diff"
    destination = "/tmp/fix-keystoneauth-plugins-unversioned.diff"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0600 /home/${var.ssh_username}/.ssh/id_rsa /home/${var.ssh_username}/cluster-defaults/clusterctl.yaml /home/${var.ssh_username}/cluster-defaults/cloud.conf /home/${var.ssh_username}/.config/openstack/clouds.yaml",
      "chmod 0755 /tmp/*.sh"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "/tmp/wait.sh"
    ]
  }

  provisioner "file" {
    source      = "extension"
    destination = "/home/${var.ssh_username}/"
  }

  # FIXME: We should get the branch (and warnings for unpushed changes from the Makefile)
  provisioner "remote-exec" {
    inline = [
      "/tmp/get_k8s_git.sh ${var.git_repo} ${var.git_reference}",
      "/home/${var.ssh_username}/bin/bootstrap.sh"
    ]
  }
}
