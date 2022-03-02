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
  default     = "Ubuntu 20.04"
}

variable "kind_flavor" {
  description = "openstack nova flavor for instance running kind (capi mgmt node)"
  type        = string
  default     = "SCS-1V:4:20"
}

variable "controller_flavor" {
  description = "openstack nova flavor for instances running the k8s management nodes"
  type        = string
  default     = "SCS-2V:4:20s"
}

variable "worker_flavor" {
  description = "openstack nova flavor for instances running the k8s worker nodes"
  type        = string
  default     = "SCS-2V:4:20"
}

variable "availability_zone" {
  description = "availability zone for openstack resources"
  type        = string
}

variable "external" {
  description = "external network for access"
  type        = string
}

variable "ssh_username" {
  description = "ssh username for instances"
  type        = string
  default     = "ubuntu"
}

variable "calico_version" {
  description = "desired version of calico"
  type        = string
  default     = "v3.22.0"
}

variable "clusterapi_version" {
  description = "desired version of cluster-api"
  type        = string
  default     = "1.0.4"
}

variable "capi_openstack_version" {
  description = "desired version of the OpenStack cluster-api provider"
  type        = string
  default     = "0.5.2"
}

variable "kubernetes_version" {
  description = "desired kubernetes version for the workload cluster"
  type        = string
  default     = "v1.21.9"
}

variable "kube_image_raw" {
  description = "convert kubernetes image to raw format for ceph backed root disks"
  type        = bool
  default     = false
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

variable "deploy_metrics_service" {
  description = "deploy metrics service into k8s-capi created clusters"
  type        = bool
  default     = true
}

variable "deploy_nginx_ingress" {
  description = "deploy NGINX ingress controller into k8s-capi created clusters"
  type        = bool
  default     = true
}

variable "deploy_cert_manager" {
  description = "deploy cert-manager into k8s-capi created clusters"
  type        = bool
  default     = false
}

variable "deploy_flux" {
  description = "install flux into k8s-capi created clusters"
  type        = bool
  default     = false
}

variable "deploy_k8s_openstack_git" {
  description = "deploy k8s openstack provider from github instead of local copy, set to true for k8s >= 1.22, dont set it for < 1.20"
  type        = bool
  default     = false
}

variable "deploy_k8s_cindercsi_git" {
  description = "deploy k8s cinder CSI provider from github instead of local copy, dito"
  type        = bool
  default     = false
}

variable "anti_affinity" {
  description = "use anti-affinity (soft for workers) to avoid k8s nodes on the same host"
  type        = bool
  default     = false
}

variable "dns_nameserver" {
  description = "nameserver to be set for subnets"
  type        = string
  default     = "9.9.9.9"
}

variable "use_cilium" {
  description = "use cilium rather than calico as CNI"
  type        = bool
  default     = false
}

variable "etcd_prio_boost" {
  description = "boost etcd priority and lengthen heartbeat"
  type        = bool
  default     = false
}

variable "etcd_unsafe_fs" {
  description = "mount controller root fs with nobarrier"
  type        = bool
  default     = false
}

