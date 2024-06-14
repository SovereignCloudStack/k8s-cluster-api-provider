# a working set for gx-scs
#
prefix            = "capi"
cloud_provider    = "gx-scs-staging"
availability_zone = "nova"
external          = "ext01"
kind_flavor       = "SCS-2V:4"
controller_flavor = "SCS-4V-16-100s"
worker_flavor     = "SCS-8V:16:100"
#image             = "Ubuntu 22.04"
#ssh_username      = "ubuntu"
controller_metadata = {
  ps_restart_after_maint = "true"
}
