# - main -
provider "openstack" {
  cloud = var.cloud_provider
}

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.1.0"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}
