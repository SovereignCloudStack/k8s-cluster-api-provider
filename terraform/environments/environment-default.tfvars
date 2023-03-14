# a working set for OpenStack
#
prefix                       = "<prefix_for_openstack_resources>"  # defaults to "capi"
cloud_provider               = "<name_for_provider>"
availability_zone            = "<az>"
external                     = "<external_network_name>"
dns_nameservers              = [ "DNS_IP1", "DNS_IP2" ]	  # defaults to [ "5.1.66.255", "185.150.99.255" ] (FF MUC)
kind_flavor                  = "<flavor>"                 # defaults to SCS-1V:4:20  (larger does not hurt)
ssh_username                 = "<username_for_ssh>"	  # defaults to "ubuntu"
clusterapi_version           = "<1.x.y>"		  # defaults to "1.3.5"
capi_openstack_version       = "<0.x.y>"		  # defaults to "0.7.1"
capo_instance_create_timeout = "<number>" # defaults to 10

image                = "<glance_image>"		  # defaults to "Ubuntu 22.04"
# Settings for testcluster
kubernetes_version   = "<v1.XX.XX>"		  # defaults to "v1.25.x"
kube_image_raw       = "<boolean>"      # defaults to "true"
calico_version       = "<v3.xx.y>"	# defaults to "v3.25.0"
controller_flavor    = "<flavor>"       # defaults to SCS-2V-4-20s (use etcd tweaks if you only have SCS-2V-4-20 in multi-controller setups)
worker_flavor        = "<flavor>"       # defaults to SCS-2V-4-20  (larger helps)
controller_count     = <number>         # defaults to 1 (0 skips testcluster creation)
worker_count         = <number>	        # defaults to 3
kind_mtu             = <number>         # defaults to 0 (autodetection)
node_cidr            = "<CIDR>"         # defaults to "10.8.0.0/20"
anti_affinity        = "<boolean>"      # defaults to "true"
use_cilium           = "<boolean>"      # defaults to "false"
use_ovn_lb_provider  = "auto/true/false"	# use OVN LB if available (auto) or force (true) or never (false), not yet recommended
deploy_nginx_ingress = "version/true/false"       # defaults to "true", you can also set vX.Y.Z if you want
deploy_cert_manager  = "version/true/false"       # defaults to "false", you can also set to vX.Y.Z if you want
deploy_flux          = "version/true/false"       # defaults to "false", you can also set to vX.Y.Z if you want
deploy_metrics       = "<boolean>"      # defaults to "true"
deploy_occm          = "<version>"      # defaults to "true" (meaning matching k8s)
deploy_cindercsi     = "<version>"      # defaults to "true", dito
etcd_unsafe_fs       = "<boolean>"      # defaults to "false", dangerous
testcluster_name     = "NAME"           # defaults to "testcluster"
restrict_kubeapi     = [ "IP/20", "IP/22" ]	# defaults to empty (fully open), use [ "none" ] for exclusive internal access
