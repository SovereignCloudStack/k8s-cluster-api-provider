# - main -
provider "openstack" {
  cloud = var.cloud_provider
}

terraform {
  required_version = ">= 1.4.6"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.43.0"
    }
    null = {
      source = "hashicorp/null"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}
