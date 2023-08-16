# a working set for gx-scs
#
cloud_provider         = "testfd2"
availability_zone      = "nova"
external               = "ext01"
kind_flavor            = "SCS-2V:4:20"
controller_flavor      = "SCS-2V:4:20"
worker_flavor          = "SCS-2V:4:20"
ssh_username           = "ubuntu"
dns_nameservers        = ["62.138.222.111", "62.138.222.222"]
controller_count       = 1
worker_count           = 2
prefix                 = "fd"
testcluster_name       = "testfd2"