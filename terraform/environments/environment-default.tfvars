# a working set for OpenStack
#
prefix               = "<prefix_for_openstack_resources>"  # defaults to "capi"
cloud_provider       = "<name_for_provider>"
availability_zone    = "<az>"
external             = "<external_network_name>"
kind_flavor          = "<flavor>"       # defaults to SCS-1V:4:10  (larger does not hurt)
ssh_username         = "<username_for_ssh>"	  # defaults to "ubuntu"
k9s_version          = "<0.xx.y>"		    # defaults to "0.25.8"
clusterapi_version   = "<1.x.y>"		    # defaults to "1.0.2"
capi_openstack_version = "<0.x.y>"		  # defaults to "0.5.0"
image                = "<glance_image>"		  # defaults to "Ubuntu 20.04"
# Settings for testcluster
kubernetes_version   = "<v1.XX.XX>"		  # defaults to "v1.21.6"
kube_image_raw       = "<boolean>"      # defaults to "false"
calico_version       = "<v3.xx.y>"		  # defaults to "v3.21.2"
controller_flavor    = "<flavor>"       # defaults to SCS-2V:4:20s (ditto)
worker_flavor        = "<flavor>"       # defaults to SCS-2V:4:20  (larger helps)
controller_count     = <number>         # defaults to 1 (0 skips testcluster creation)
worker_count         = <number>	        # defaults to 3
kind_mtu             = <number>         # defaults to 0 (autodetection)
node_cidr            = "<CIDR>"         # defaults to "10.8.0.0/20"
anti_affinity        = "<boolean>"      # defaults to "false"
deploy_nginx_ingress = "<boolean>"      # defaults to "true"
deploy_cert_manager  = "<boolean>"      # defaults to "false"
deploy_flux          = "<boolean>"      # defaults to "false"
deploy_metrics_service   = "<boolean>"  # defaults to "true"
deploy_k8s_openstack_git = "<boolean>"  # defaults to "false", enable for k8s >= 1.22, dont for < 1.20
deploy_k8s_cindercsi_git = "<boolean>"  # defaults to "false", dito
