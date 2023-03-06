variable "cloud_provider" {
  description = "cloudprovider name"
  type        = string
}

variable "prefix" {
  description = "a prefix name for resources"
  type        = string
  default     = "capi"
}

variable "image" {
  description = "openstack glance image for nova instances"
  type        = string
  default     = "Ubuntu 22.04"
}

variable "kind_flavor" {
  description = "openstack nova flavor for instance running kind (capi mgmt node)"
  type        = string
  default     = "SCS-1V:4:20"
}

variable "controller_flavor" {
  description = "openstack nova flavor for instances running the k8s management nodes"
  type        = string
  default     = "SCS-2C:4:20s"
}

variable "worker_flavor" {
  description = "openstack nova flavor for instances running the k8s worker nodes"
  type        = string
  default     = "SCS-2V:4:20"
}

variable "availability_zone" {
  description = "availability zone for openstack resources"
  type        = string
}

variable "external" {
  description = "external network for access"
  type        = string
}

variable "ssh_username" {
  description = "ssh username for instances"
  type        = string
  default     = "ubuntu"
}

variable "calico_version" {
  description = "desired version of calico"
  type        = string
  default     = "v3.25.0"
}

variable "clusterapi_version" {
  description = "desired version of cluster-api"
  type        = string
  default     = "1.3.5"
}

variable "capi_openstack_version" {
  description = "desired version of the OpenStack cluster-api provider"
  type        = string
  default     = "0.7.1"
}

variable "kubernetes_version" {
  description = "desired kubernetes version for the workload cluster"
  type        = string
  default     = "v1.23.x"
}

variable "kube_image_raw" {
  description = "convert kubernetes image to raw format for ceph backed root disks"
  type        = bool
  default     = true
}

variable "image_registration_extra_flags" {
  description = "pass extra parameters to image registration"
  type        = string
  default     = ""
}

variable "kind_mtu" {
  description = "MTU used in the kind cluster (0=autodetect), k8s cluster is 50 smaller"
  type        = number
  default     = 0
}

variable "worker_count" {
  description = "number of worker nodes in testcluster"
  type        = number
  default     = 3
}

variable "controller_count" {
  description = "number of control plane management nodes in testcluster"
  type        = number
  default     = 1
}

variable "node_cidr" {
  description = "network addresses (CIDR) for the k8s nodes"
  type        = string
  default     = "10.8.0.0/20"
}

variable "deploy_metrics" {
  description = "deploy metrics service into k8s-capi created clusters"
  type        = bool
  default     = true
}

variable "deploy_nginx_ingress" {
  description = "deploy NGINX ingress controller (version) into k8s-capi created clusters"
  type        = string
  default     = "true"
}

variable "deploy_cert_manager" {
  description = "deploy cert-manager (version) into k8s-capi created clusters"
  type        = string
  default     = "false"
}

variable "deploy_flux" {
  description = "install flux (version) into k8s-capi created clusters"
  type        = string
  default     = "false"
}

variable "deploy_occm" {
  description = "deploy k8s openstack provider version. True matches k8s version"
  type        = string
  default     = "true"
}

variable "deploy_cindercsi" {
  description = "deploy k8s cinder CSI provider version. True matches k8s version"
  type        = string
  default     = "true"
}

variable "anti_affinity" {
  description = "use anti-affinity (soft for workers) to avoid k8s nodes on the same host"
  type        = bool
  default     = true
}

variable "dns_nameservers" {
  description = "array of nameservers to be set for subnets, prefer local DNS servers if available"
  type        = list(string)
  default     = ["5.1.66.255", "185.150.99.255"]
}

variable "use_cilium" {
  description = "use cilium rather than calico as CNI"
  type        = bool
  default     = false
}

variable "etcd_prio_boost" {
  description = "boost etcd priority and lengthen heartbeat (ignored, always on)"
  type        = bool
  default     = true
}

variable "etcd_unsafe_fs" {
  description = "mount controller root fs with nobarrier"
  type        = bool
  default     = false
}

variable "git_branch" {
  description = "k8s-cluster-api-provider git branch to be checked out on mgmtserver"
  type        = string
  default     = "master"
}

variable "git_repo" {
  description = "github repository url that should be used for the deployment"
  type        = string
  default     = "https://github.com/SovereignCloudStack/k8s-cluster-api-provider"
}

variable "testcluster_name" {
  description = "name of the testcluster optionally created during bootstrap"
  type        = string
  default     = "testcluster"
}
