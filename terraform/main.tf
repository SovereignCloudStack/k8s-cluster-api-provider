# - main -
provider "openstack" {
  cloud = var.cloud_provider
}

terraform {
  required_version = ">= 0.13"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.32.0"
    }

    local = {
      source = "hashicorp/local"
    }
  }
}
