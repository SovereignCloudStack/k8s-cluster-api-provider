variable "cloud_provider" {
  description = "cloudprovider name"
  type        = string
}

variable "prefix" {
  description = "a prefix name for resources"
  type        = string
  default     = "capi"
}

variable "image" {
  description = "openstack glance image for nova instances"
  type        = string
  default     = "Ubuntu 22.04"
}

variable "kind_flavor" {
  description = "openstack nova flavor for instance running kind (capi mgmt node)"
  type        = string
  default     = "SCS-2V-4"
}

variable "controller_flavor" {
  description = "openstack nova flavor for instances running the k8s management nodes"
  type        = string
  default     = "SCS-2V-4-20s"
}

variable "worker_flavor" {
  description = "openstack nova flavor for instances running the k8s worker nodes"
  type        = string
  default     = "SCS-2V-4-20s"
}

variable "availability_zone" {
  description = "availability zone for openstack resources"
  type        = string
}

variable "external" {
  description = "external/public network for access"
  type        = string
  default     = ""
  # default   = data.openstack_networking_network_v2.extnet.name
}

variable "ssh_username" {
  description = "ssh username for instances"
  type        = string
  default     = "ubuntu"
}

variable "calico_version" {
  description = "desired version of calico"
  type        = string
  default     = "v3.26.1"
}

variable "clusterapi_version" {
  description = "desired version of cluster-api"
  type        = string
  default     = "1.3.8"
}

variable "capi_openstack_version" {
  description = "desired version of the OpenStack cluster-api provider"
  type        = string
  default     = "0.7.3"
}

variable "kubernetes_version" {
  description = "desired kubernetes version for the workload cluster"
  type        = string
  default     = "v1.25.x"
}

variable "kube_image_raw" {
  description = "convert kubernetes image to raw format for ceph backed root disks"
  type        = bool
  default     = true
}

variable "image_registration_extra_flags" {
  description = "pass extra parameters to image registration"
  type        = string
  default     = ""
}

variable "kind_mtu" {
  description = "MTU used in the kind cluster (0=autodetect), k8s cluster is 50 smaller"
  type        = number
  default     = 0
}

variable "worker_count" {
  description = "number of worker nodes in testcluster"
  type        = number
  default     = 3
}

variable "controller_count" {
  description = "number of control plane management nodes in testcluster"
  type        = number
  default     = 1
}

variable "node_cidr" {
  description = "network addresses (CIDR) for the k8s nodes"
  type        = string
  default     = "10.8.0.0/20"
}

variable "pod_cidr" {
  description = "network addresses (CIDR) for the k8s pods"
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "network addresses (CIDR) for the k8s services"
  type        = string
  default     = "10.96.0.0/12"
}

variable "deploy_metrics" {
  description = "deploy metrics service into k8s-capi created clusters"
  type        = bool
  default     = true
}

variable "deploy_nginx_ingress" {
  description = "deploy NGINX ingress controller (version) into k8s-capi created clusters"
  type        = string
  default     = "true"
}

variable "deploy_gateway_api" {
  description = "deploy k8s Gateway API CRDs along with ciliums implementation of Gateway API, only works in conjunction with use_cilium=true"
  type        = string
  default     = "false"
}

variable "deploy_cert_manager" {
  description = "deploy cert-manager (version) into k8s-capi created clusters"
  type        = string
  default     = "false"
}

variable "deploy_flux" {
  description = "install flux (version) into k8s-capi created clusters"
  type        = string
  default     = "false"
}

variable "deploy_occm" {
  description = "deploy k8s openstack provider version. True matches k8s version"
  type        = string
  default     = "true"
}

variable "deploy_cindercsi" {
  description = "deploy k8s cinder CSI provider version. True matches k8s version"
  type        = string
  default     = "true"
}

variable "anti_affinity" {
  description = "use anti-affinity (soft for workers) to avoid k8s nodes on the same host"
  type        = bool
  default     = true
}

variable "dns_nameservers" {
  description = "array of nameservers to be set for subnets, prefer local DNS servers if available"
  type        = list(string)
  default     = ["5.1.66.255", "185.150.99.255"]
}

variable "use_cilium" {
  description = "use cilium (version) rather than calico as CNI"
  type        = string
  default     = "true"
}

variable "cilium_binaries" {
  description = "cilium and hubble CLI versions in the vA.B.C;vX.Y.Z format"
  type        = string
  default     = "v0.15.0;v0.11.6"
}

variable "etcd_unsafe_fs" {
  description = "mount controller root fs with nobarrier"
  type        = bool
  default     = false
}

variable "git_reference" {
  description = "k8s-cluster-api-provider git reference to be checked out on mgmtserver"
  type        = string
  default     = "main"
}

variable "git_repo" {
  description = "github repository url that should be used for the deployment"
  type        = string
  default     = "https://github.com/SovereignCloudStack/k8s-cluster-api-provider"
}

variable "testcluster_name" {
  description = "name of the testcluster optionally created during bootstrap"
  type        = string
  default     = "testcluster"
}

variable "use_ovn_lb_provider" {
  description = "usage of OVN octavia provider (false, auto, true)"
  type        = string
  default     = "false"
  validation {
    condition     = contains(["false", "auto", "true"], var.use_ovn_lb_provider)
    error_message = "Invalid setting for use_ovn_lb_provider variable."
  }
}

variable "restrict_kubeapi" {
  description = "array of IP ranges (CIDRs) that get exclusive access. Leave open for all, none for exclusive internal access"
  type        = list(string)
  default     = []
}


variable "capo_instance_create_timeout" {
  description = "time to wait for an openstack machine to be created (in minutes)"
  type        = number
  default     = 5
}

variable "containerd_registry_files" {
  type = object({
    hosts = optional(set(string), ["./files/containerd/docker.io"]),
    certs = optional(set(string), [])
  })
  description = <<EOF
    containerd registry host config files referenced by attributes `hosts` and `certs`.
    Attributes:
      hosts (set): Additional registry host config files for containerd. The filename should
        reference the registry host namespace. Files defined in this set will be copied into the `/etc/containerd/certs.d`
        directory on each cluster node. The default `docker.io` registry host file instructs containerd to use
        `registry.scs.community` container registry instance as a public mirror of DockerHub container registry.
      certs (set): Additional client and/or CA certificate files needed for containerd authentication against
        registries defined in `hosts`. Files defined in this set will be copied into the `/etc/containerd/certs`
        directory on each cluster node.

    visit containerd docs for further details on how to configure registry hosts https://github.com/containerd/containerd/blob/main/docs/hosts.md
    EOF
  default     = {}
}

variable "deploy_harbor" {
  description = <<EOF
  Deploy Harbor container registry. If enabled, the SCS container registry instance of the Harbor will be deployed
  as defined in the k8s-harbor [project](https://github.com/SovereignCloudStack/k8s-harbor), which is used
  also for the SCS community Harbor instance available at https://registry.scs.community/. It deploys `flux2` as a
  mandatory dependency and may deploy also `cert-manager`, `ingress-nginx` and `Cinder CSI` dependencies,
  see the `harbor_config` variable. It also expects that the Swift object store is available in the targeting
  OpenStack project. A Swift bucket and ec2 credentials will be created and used for storing container image blobs.
  EOF
  type        = bool
  default     = false
}

variable "harbor_config" {
  type = object({
    domain_name   = optional(string, ""),
    issuer_email  = optional(string, ""),
    persistence   = optional(bool, false),
    database_size = optional(string, "1Gi"),
    redis_size    = optional(string, "1Gi"),
    trivy_size    = optional(string, "5Gi") # x 2 replicas
  })
  description = <<-EOF
  Harbor container registry configuration options.

  Attributes:
    domain_name (string, optional): Harbor domain name. If set, Harbor services will be exposed via the `Ingress`
      resource and secured by SSL/TLS certificate. The certificate will be issued from Let’s Encrypt using the
      standard ACME HTTP-01 challenge. This will also force the deployment of dependent services such as
      `cert-manager` and `ingress-nginx`. If not set, Harbor services will be exposed via the `ClusterIP` service type.
      See ingress [environment](files/kubernetes-manifests.d/harbor/envs/ingress/) for further details.
    issuer_email (string, optional): Email address for the cert-manager issuer ACME account used for issuing Harbor
      certificate. It will be used to contact you in case of issues with your account or certificates,
      including expiry notification emails. Relevant only when `domain_name` is set.
    persistence (bool, optional): Enable persistence for the Harbor components.
      This will force the deployment of `Cinder CSI`.
    database_size (string, optional): PV size of the Harbor database. Relevant only when `persistence` is true.
      Defaults to `1Gi`.
    redis_size (string, optional): PV size of the Harbor k-v database (Redis). Relevant only when `persistence` is true.
      Defaults to `1Gi`.
    trivy_size (string, optional): PV size of the Trivy. Relevant only when `persistence` is true.
      Defaults to `5Gi` for each of 2 Trivy replicas.
  EOF
  default     = {}
}
