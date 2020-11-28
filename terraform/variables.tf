variable "cloud_provider" {
  description = "cloudprovider name"
  type        = string
}

variable "prefix" {
  description = "a prefix name for resources"
  type        = string
}

variable "image" {
  description = "openstack glance image for nova instances"
  type        = string
}

variable "flavor" {
  description = "openstack nova flavor for nova instances"
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

resource "random_password" "k3s_token" {
  length           = 32
  special          = true
  override_special = "=_%@"
}
