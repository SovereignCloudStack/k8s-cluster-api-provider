# a working set for OpenStack
#
prefix               = "<prefix_for_openstack_resources>"  # defaults to "capi"
cloud_provider       = "<name_for_provider>"
availability_zone    = "<az>"
external             = "<external_network_name>"
kind_flavor          = "<flavor>"       # Use SCS-2V-4-10 (larger does not hurt)
controller_flavor    = "<flavor>"	# Use SCS-2V-4-20 (ditto)
worker_flavor        = "<flavor>"	# Use SCS-2V-4-20 (larger helps)
controller_count     = <number>         # defaults to 1 (0 skips testcluster creation)
worker_count         = <number>	        # defaults to 3
image                = "<glance_image>"
ssh_username         = "<username_for_ssh>"
kubernetes_version   = "<v1.XX.XX>"	
kubernetes_namespace = "<namespace_for_testcluster>"	# defaults to "default"
kube_image_raw       = "<boolean>"	# defaults to "false"
kind_mtu             = <number> 	# defaults to 1400

