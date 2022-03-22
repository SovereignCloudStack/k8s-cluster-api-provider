# Release Notes for SCS k8s-capi-provider for R2

k8s-cluster-api-provider was provided with R1 of Sovereign
Cloud Stack and has since seen major updates.

R2 was released on 2022-03-23.

## Updated software

### capi v1.0.x and openstack capi provider 0.5.x

The kubernetes cluster API has finally reached a stable status with the
`v1beta1` API versions and v1.0.x software versions. The OpenStack
provider v0.5.x works with the v1.0.x cluster API.

### k8s versions (1.19 -- 1.23)

We test the kubernetes versions 1.19 -- 1.23 with the R2 cluster-api
solution. We had tested 1.18 successfully before, so it will probably
still work. 

### calico 3.22.x, cilium 1.11.x, helm 3.8.x, sonobuoy 0.56.x, k9s 0.25.x, kind 0.12.x

We regularly update to the latest stable versions.

### cert-manager 1.7.x, nginx-ingress 1.1.x

This also applies for the included standard cluster services.

## New features

### Independent Per-cluster settings (#176)

Previously, all clusters were supposed to mainly differ by the settings
in clusterctl.yaml. By creating directories for each cluster, using and
preserving separate cluster-templates becomes easy. Images (k8s versions)
can be different for each cluster and are registered with distinct
names (#128).

### Use artifacts from git on management node (#176)

Previously, to benefit from bug fixes and improvements in the
k8s-cluster-api-provider repository, one would have needed to deploy
a new management node including these improvements (or do some tedious
manual reconciliation). We now git clone the repository on the management
node and use it directly, so we can use `git pull` there to update.

### cilium support (#130)

[Cilium](https://cilium.io/) makes intensive use of [eBPF](https://ebpf.io)
to create a high performant network overlay for k8s. It also includes
tooling to observe and analyze flows (hubble). We support Cilium as an
alternative to Calico. While we intend to make this the default CNI solution
for SCS clusters, currently it's opt-in and you need to set `USE_CILIUM: true`
in your `clusterctl.yaml`.

In our testing, we currently see four failed CNCF conformance tests with cilium,
see issue [#144](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/144). 

### cert-manager (#118, #124)

Support for deploying [cert-manager](https://cert-manager.io/) into clusters has been
added to simplify the handling of certificates.

### flux (#123)

Support for deploying [flux](https://fluxcd.io/) into new clusters
has been added to help easing the gitops style automation for handling
deployments.

### Anti-Affinity

We tell OpenStack to avoid scheduling kubernetes nodes on the same hosts (hypervisors).
For Kubernetes control nodes, we set a hard anti-affinity rule, while we use
a soft-anti-affinity role for the worker nodes. This is enabled by default.

### etcd (#147)

We have added workarounds for etcd (by increasing the heartbeat interval and using
async filesystem options) to allow stable setups with multiple control nodes
on clouds that can not guarantee low-latency storage access (due to not exposing
local disks/SSDs/NMVEs). While not ideal, a multi controller cluster this workaround
is still deemed more resilient than a single-node controller setup which was the
only stable choice on such clouds before.

### MTU autodetection (#110)

Some clouds use MTUs smaller than the standard 1500 -- while the SCS capi user
could have adjusted this value to ensure everything works before, we now recommend
a setting of `0` which causes the autodetection to do its job.

### per-cluster app cred (#177)

We use an unrestricted application credential on the management node now,
so we can create per-cluster application credentials on it for better
isolation. Note that pre-cluster application credentials have not yet
been implemented.

## Important Bugfixes

### DNS (#164)

Previously, only one DNS server could be supplied using the `OPENSTACK_DNS_NAMESERVERS`
setting, which contradicts best practice for DNS resolution. We can now supply a comma-
separated list and default to the excellent name service provided by 
(FFMUC)[https://ffmuc.net/wiki/doku.php?id=knb:dns]:
`"[ 5.1.66.255, 185.150.99.255 ]"`.
We had experienced UDP:53 failures with quad9 
(which was the old default) before.

### loadbalancer name conflict (#93, #191)

The loadbalancer would previoiusly be created without encoding the name of cluster in
its name -- this would lead to conflicts and thus result in the inability to manage
several clusters with loadbalancer-backed ingress controllers to be created in the
same OpenStack project without manual intervention.

### nginx-ingress health-monitor and proxy support (#175)

The upstream nginx-ingress controller deployment files uses an `externalTrafficPolicy: Local`
setting, which avoids unnecessary hops and also avoids forwarded requests that appear to
originate from the internal cluster. It however requires the L3 loadbalancer to use a
health-monitor. This was not explicitly set in the past, so we could end up 10 seconds on
the initial connection attempt (to a 3-node cluster). This has been addressed by
kustomization of the nginx-ingress deployment.
[#175](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/175).

Using the kustomization, the option `NGINX_INGRESS_PROXY` setting has also been introduced,
allowing the http/https services to receive the real IP address via the PROXY protocol.
It is disabled by default; while we expect most users to find this desirable, it can create
challenges for internal access to the nginx ingress.

## Upgrade/Migration notes

### Incompatible changes

* The `OPENSTACK_ANTIAFFINITY` `clusterctl.yaml` setting, introduced during the
  R2 development cycle was renamed to `OPENSTACK_ANTI_AFFINITY` for consistency
  reasons (#152).
* The `tfvars` setting `deploy_metrics_service` was rename to `deploy_metrics` (#149).
* As mentioned before, we do support multiple nameservers now. The `clusterctl.yaml`
  setting's name used the plural before, but not so the `tfvars`. It was names
  `dns_nameserver` and now is called `dns_nameservers` (#164).
* We have flags `DEPLOY_K8S_OPENSTACK_GIT` to indicate that we want the latest git
  master version for the OpenStack Cloud Controller Manager (OCCM) deployed rather
  than the older version referenced here. Same story with `DEPLOY_K8S_CINDERCSI_GIT`.
  This has been replaced with the settings `DEPLOY_OCCM` and `DEPLOY_CINDERCSI`,
  which can be set to either `false` (not recommended), `true` (the default,
  picking a good version that matches your k8s version) or an explicit version
  number such as e.g. `v1.21.1`. The default is typically a good choice.
  Choose `master` if you want the latest and greatest (which was the old beahviro
  if you set the `.._GIT` settings to `true`.

### Changed defaults

* As SCS clouds are using ceph backed storage for the images, we convert the clusterapi
  images to raw format by default now (#165).
* If you don't specify a `kubernetes_version`, the default now is v1.22.7.
* For k8s-1.22, it's much better to use the cinder/occm git versions, so we enable
  them by default now (#165).

## Removals and deprecations

None.

## Known issues and limitations

### metrics with --kubelet-insecure-tls (#148)

Like most kubeadm based setups, we used --kubelet-insecure-tls for the metric
service to be allowed to talk to kubelets to retrieve metrics. This can be improved.

### No removal of services from `create_cluster.sh` (#137)

You can call `create_cluster.sh` many times to apply changes to your
workload cluster -- it currently however does not remove any of the deployed
standard services that you might have had enabled before and now set to
`false`. (We will require a `--force-remove` option or so to ensure that
users are aware of the risks.)

### No support for changing b/w calico and cilium (#131)

Switching between the two CNI alternatives is currently not facilitated
by the `create_cluster.sh` script. It can be done by removing the
current CNI manually (delete the deployment yaml or cilium uninstall)
and then calling `create_cluster.sh`. However, this has the potential
to disrupt the workloads in your workload clusters.

### Four CNCF conformance test fails with cilium (#144)

We want to understand whether these four failures could be avoided by tweaking
the configuration or whether those are commonly ignored. The investigation
still has to be done.

## Future roadmap

### helm charts

The [capi-helm-charts](https://github.com/stackhpc/capi-helm-charts) from
[StackHPC](https://stackhpc.com) are still on the roadmap as our future
tooling for managing Clusters on SCS, repositioning the scripts based
tooling to be used for PoCs rather than production deployments.

### harbor (#139)

We have a harbor registry for hosting (and scanning) image artifacts
for the SCS community. This has been built using the 
[SCS k8s-harbor](https://github.com/SovereignCloudStack/k8s-harbor) repository.
We intend to provide an easy way to create ow harbor instances along with
SCS cluster management.

### gitops ([Docs/#47](https://github.com/SovereignCloudStack/Docs/pull/47))

We want to enable declarative gitops style cluster management, please see
this [pull request]((https://github.com/SovereignCloudStack/Docs/pull/47)) 
for our Design Docs.

## Conformance

With Calico CNI, the k8s clusters created with our SCS cluster-API based
cluster management solution pass the CNCF conformance tests as run by
[sonobuoy](https://sonobuoy.io/).

With the gitops approach, we intend to standardize the
`clusterctl.yaml` settings to allow a straightforward approach to
declarative cluster management. This is intended for R3 (9/2022).

## Branching

We tag the R2 branch with the v3.0.0 tag and create a v3.0.x branches
for users that want to exclusively see bug and security fixes.
We will also create a v3.x branch for minor releases (which
however might never see anything beyond what we put into v3.0.x
if we don't create a minor release). 
If we decide to create a minor release, we would also create a 
v3.1.0 tag and a v3.1.x branch.
These branches will receive updates until the end of October 2022.

## Contribution

We appreciate contribution to strategy and implemention, please join
our community -- or just leave input on the github issues and PRs.
Have a look at our [contributor guide](https://scs.community/docs/contributor/).
We also have worked on a [Code of Conduct](https://github.com/SovereignCloudStack/Docs/pull/26)
to document the expected behavior of contributors and how we deal with
cases where individuals fail to meet the expectation.
