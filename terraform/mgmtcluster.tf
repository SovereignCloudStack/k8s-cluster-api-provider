# - ssh keypair -
resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.prefix}-keypair"
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
  clouds = lookup(lookup(yamldecode(file("${var.clouds_yaml_path}/clouds.yaml")), "clouds"), var.cloud_provider)
  secure = lookup(lookup(yamldecode(file("${var.clouds_yaml_path}/secure.yaml")), "clouds"), var.cloud_provider)
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
  - content: |
      [Unit]
      Description=Docker Set MTU to ${var.kind_mtu}
      After=docker.service
      Requires=docker.socket
      
      [Service]
      Type=oneshot
      ExecStart=/bin/ip link set dev docker0 mtu ${var.kind_mtu}
      
      [Install]
      WantedBy=multi-user.target
    owner: root:root
    path: /etc/systemd/system/docker-mtu.service
    permissions: '0644'
runcmd:
  - echo nf_conntrack > /etc/modules-load.d/90-nf_conntrack.conf
  - modprobe nf_conntrack
  - echo net.netfilter.nf_conntrack_max=131072 > /etc/sysctl.d/90-conntrack_max.conf
  - sysctl -w -p /etc/sysctl.d/90-conntrack_max.conf
  - mkdir /etc/docker
  - mv /tmp/daemon.json /etc/docker/daemon.json
  - groupadd docker
  - usermod -aG docker ${var.ssh_username}
  - apt -y install docker.io yamllint qemu-utils
  - systemctl enable --now docker-mtu
EOF

  connection {
    host        = openstack_networking_floatingip_v2.mgmtcluster_floatingip.address
    private_key = openstack_compute_keypair_v2.keypair.private_key
    user        = var.ssh_username
  }

  provisioner "file" {
    source      = "files/wait.sh"
    destination = "/home/${var.ssh_username}/wait.sh"
  }

  provisioner "file" {
    source      = "files/install_kind.sh"
    destination = "/home/${var.ssh_username}/install_kind.sh"
  }

  provisioner "file" {
    content     = openstack_compute_keypair_v2.keypair.private_key
    destination = "/home/${var.ssh_username}/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "files/bootstrap.sh"
    destination = "/home/${var.ssh_username}/bootstrap.sh"
  }

  provisioner "file" {
    source      = "files/deploy_cluster_api.sh"
    destination = "/home/${var.ssh_username}/deploy_cluster_api.sh"
  }

  provisioner "file" {
    source      = "files/deploy_cluster.sh"
    destination = "/home/${var.ssh_username}/deploy_cluster.sh"
  }

  provisioner "file" {
    source      = "files/delete_cluster.sh"
    destination = "/home/${var.ssh_username}/delete_cluster.sh"
  }

  provisioner "file" {
    source      = "files/cleanup.sh"
    destination = "/home/${var.ssh_username}/cleanup.sh"
  }

  provisioner "file" {
    content     = templatefile("files/template/clusterctl.yaml.tmpl", { kubernetes_version = var.kubernetes_version, availability_zone = var.availability_zone, external = var.external, image = var.image, controller_flavor = var.controller_flavor, worker_flavor = var.worker_flavor, cloud_provider = var.cloud_provider, worker_count = var.worker_count, controller_count = var.controller_count, kind_mtu = var.kind_mtu, namespace = var.kubernetes_namespace, prefix = var.prefix })
    destination = "/home/${var.ssh_username}/clusterctl.yaml"
  }

  provisioner "file" {
    content     = templatefile("files/template/upload_capi_image.sh.tmpl", { kubernetes_version = var.kubernetes_version, provider = var.cloud_provider, kube_image_raw = var.kube_image_raw, image_registration_extra_flags = var.image_registration_extra_flags })
    destination = "/home/${var.ssh_username}/upload_capi_image.sh"
  }

  provisioner "file" {
    content     = templatefile("files/template/wait_capi_image.sh.tmpl", { kubernetes_version = var.kubernetes_version, provider = var.cloud_provider })
    destination = "/home/${var.ssh_username}/wait_capi_image.sh"
  }

  provisioner "file" {
    content     = templatefile("files/template/clouds.yaml.tmpl", { cloud_provider = var.cloud_provider, clouds = local.clouds, secure = local.secure })
    destination = "/home/${var.ssh_username}/clouds.yaml"
  }

  provisioner "file" {
    content     = templatefile("files/template/cloud.conf.tmpl", { cloud_provider = var.cloud_provider, clouds = local.clouds, secure = local.secure })
    destination = "/home/${var.ssh_username}/cloud.conf"
  }
  provisioner "file" {
    source      = "files/template/cluster-template.yaml"
    destination = "/home/${var.ssh_username}/cluster-template.yaml"
  }

  provisioner "file" {
    source      = "files/kubernetes-manifests.d/"
    destination = "/home/${var.ssh_username}"
  }

  provisioner "file" {
    content     = templatefile("files/template/clusterctl_template.sh", { cloud_provider = var.cloud_provider })
    destination = "/home/${var.ssh_username}/clusterctl_template.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x *.sh"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "bash /home/ubuntu/wait.sh"
    ]
  }

  provisioner "file" {
    source      = "extension"
    destination = "/home/${var.ssh_username}/"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0600 /home/${var.ssh_username}/.ssh/id_rsa /home/${var.ssh_username}/clusterctl.yaml /home/${var.ssh_username}/cloud.conf /home/${var.ssh_username}/clouds.yaml",
      "bash /home/${var.ssh_username}/bootstrap.sh"
    ]
  }
}
