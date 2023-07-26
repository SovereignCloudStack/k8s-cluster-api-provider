# a working set for OpenStack
#
cloud_provider       = "regio"
availability_zone    = "nova"
external             = "public"
kind_flavor          = "SCS-2V-4-20s"
# Settings for testcluster
worker_flavor        = "SCS-2V-8-20"       # defaults to SCS-2V-4-20  (larger helps)
anti_affinity        = "true"      # defaults to "true"
