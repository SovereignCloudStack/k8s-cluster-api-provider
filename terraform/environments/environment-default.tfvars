# a working set for OpenStack
#
prefix               = "<prefix_for_openstack_resources>"  # defaults to "capi"
cloud_provider       = "<name_for_provider>"
availability_zone    = "<az>"
external             = "<external_network_name>"
kind_flavor          = "<flavor>"       # defaults to SCS-1V:4:10  (larger does not hurt)
controller_flavor    = "<flavor>"       # defaults to SCS-2V:4:20s (ditto)
worker_flavor        = "<flavor>"       # defaults to SCS-2V:4:20  (larger helps)
controller_count     = <number>         # defaults to 1 (0 skips testcluster creation)
worker_count         = <number>	        # defaults to 3
image                = "<glance_image>"		  # defaults to "Ubuntu 20.04"
ssh_username         = "<username_for_ssh>"	  # defaults to "ubuntu"
kubernetes_version   = "<v1.XX.XX>"		  # defaults to "v1.21.5"
kubernetes_namespace = "<namespace_testcluster>"  # defaults to "default"
kube_image_raw       = "<boolean>"      # defaults to "false"
kind_mtu             = <number>         # defaults to 1400
node_cidr            = "CIDR"           # defaults to "10.8.0.0/20"
deploy_nginx_ingress = "<boolean>"      # defaults to "true"
deploy_metrics_service   = "<boolean>"  # defaults to "true"
deploy_k8s_openstack_git = "<boolean>"  # defaults to "false"
deploy_k8s_cindercsi_git = "<boolean>"  # defaults to "false"
