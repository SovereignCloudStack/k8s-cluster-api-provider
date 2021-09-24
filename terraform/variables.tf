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
  default     = "SCS-1V:4:10"
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

variable "kubernetes_version" {
  description = "desired kubernetes version for the workload cluster"
  type        = string
  default     = "v1.21.4"
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
  description = "inner MTU used in the kind cluster on the capi-mgmtnode"
  type        = number
  default     = 1400
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

variable "kubernetes_namespace" {
  description = "namespace for the testcluster"
  type        = string
  default     = "default"
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

variable "deploy_k8s_openstack_git" {
  description = "deploy k8s openstack provider from github instead of local copy"
  type        = bool
  default     = false
}

variable "deploy_k8s_cindercsi_git" {
  description = "deploy k8s cinder CSI provider from github instead of local copy"
  type        = bool
  default     = false
}
