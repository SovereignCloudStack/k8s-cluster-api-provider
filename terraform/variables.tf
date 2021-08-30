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
}

variable "kind_flavor" {
  description = "openstack nova flavor for instance running kind (capi mgmt node)"
  type        = string
}

variable "controller_flavor" {
  description = "openstack nova flavor for instances running the k8s management nodes"
  type        = string
}

variable "worker_flavor" {
  description = "openstack nova flavor for instances running the k8s worker nodes"
  type        = string
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

variable "clouds_yaml_path" {
  description = "where to find clouds and secure.yaml"
  type        = string
  default     = "."
}
