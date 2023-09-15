# Release Notes of SCS k8s-capi-provider for R5

## Updated software

| Software       | Version | Note                                                                                                                                                                            |
|----------------|---------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Terraform      | v1.4.6  | [#515](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/515) Given Hashicorp change of license to BSL we pinned terraform to version < 1.6.0.               |
| flux2          | 0.41.2  | This version is well-tested, the next upgrade will come later.                                                                                                                  |
| sonobuoy       | 0.56.x  | v0.56.17 adds support for the latest k8s 1.27 version.                                                                                                                          |
| Cilium         | 1.14.1  |                                                                                                                                                                                 |
| Cilium cli     | v0.15.7 |                                                                                                                                                                                 |
| Cilium Hubble  | v0.12.0 |                                                                                                                                                                                 |
| cert-manager   | 1.12.x  |                                                                                                                                                                                 |
| kind           | 0.20.0  |                                                                                                                                                                                 |
| helm           | 3.12.x  |                                                                                                                                                                                 |
| metrics-server | 0.6.4   |                                                                                                                                                                                 |
| nginx-ingress  | 1.8.x   | Supports only k8s version >= 1.24. We dropped support for older k8s versions. [supported versions table](https://github.com/kubernetes/ingress-nginx#supported-versions-table). |
| k9s            | 0.27.x  | Instead of using just the latest version, it has been pinned now.                                                                                                               |
| calico         | 3.26.x  |                                                                                                                                                                                 |
| capi           | v1.5.1  | [Kubernetes Cluster API Provider](https://cluster-api.sigs.k8s.io/)                                                                                                             |
| capo           | 0.7.3   | [OpenStack Provider for CAPI](https://cluster-api-openstack.sigs.k8s.io/)                                                                                                       |
| ubuntu         | 22.04   | See [below](#ubuntu-2204).                                                                                                                                                      |

### k8s versions (1.24 -- 1.27)

We test Kubernetes versions 1.24 -- 1.27 with the R5 Cluster API
solution. We had tested earlier versions (down to 1.18) successfully before,
and we don't expect them to break, but these are no longer supported
upstream and no fresh node images are provided by us.

Please note that k8s-v1.25 brought the removal of the deprecated Pod Security
Policies (PSPs) and brought
[Pod Security Standards (PSS)](https://kubernetes.io/blog/2022/08/25/pod-security-admission-stable/)
instead.
The end of life for v1.25 is at the end of October.

Release notes for upstream Kubernetes can be found [here](https://github.com/kubernetes/kubernetes/releases).
Please read the [API deprecation notes](https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-27)
when you move your workloads to the latest k8s versions.

Kubernetes v1.28 can be deployed as a technical preview for now, but
we expect that it will be stabilized soon.

## New features

### Ubuntu 22.04

We upgraded capi management server to the 22.04 LTS release in the R4.
Now [#434](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/434),
we upgraded also images which are used for the k8s control plane and worker nodes.
Before the upgrade, testing [#409](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/409)
was done and revealed two additional problems.
Both problems were investigated, fixes were introduced to the upstream and were successfully
merged [kubernetes-sigs/image-builder/#1146](https://github.com/kubernetes-sigs/image-builder/pull/1146),
[kubernetes-sigs/image-builder/#1182](https://github.com/kubernetes-sigs/image-builder/pull/1182).
The Ubuntu 22.04 LTS node images are available starting from k8s version 1.25.11, 1.26.6 and 1.27.3.

### Support for Debian 12

From [#509](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/509), Debian 12 is supported as a
management server OS as an alternative to the default Ubuntu 22.04.

### Storage snapshots

The CSI driver deployed with SCS (in R4) did not have the needed snapshot-controller
container ([#408](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/408))
deployed while it already did deploy the needed snapshot CRDs.
The missing container has been added now
([#415](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/415))
and snapshot functionality is validated using the check-csi CNCF/sonobuoy test.

(This fix was also backport to the maintained R4 (v5.x and v5.0.x) branches.)

### Cilium is the default CNI now

We have decided to use Cilium as default
CNI, [#431](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/431).
You can still override this and set `USE_CILIUM="false"` if you prefer Calico.

### Support for diskless flavors

The SCS
[flavor spec v3](https://github.com/SovereignCloudStack/standards/blob/main/Standards/scs-0100-v3-flavor-naming.md)
makes the flavors with root disks only recommended (except for the two new SSD flavors).
The used `cluster-template.yaml` now is dynamically patched to allocate a root disk
as needed when diskless flavors are being used,
[#424](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/424).

This change requires installation of `jq`.

(This fix is backported to the maintained R4 branch v5.x.)

### Custom CA

From [#460](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/460), the k8s-cluster-api-provider
supports a situation when communication with OpenStack API is protected by the certificate issued by custom or private
CA. All you have to do is provide `cacert` option in your clouds.yaml configuration file. CA cert will be copied
to the management and workload cluster so provide only necessary certificates in that file.
You can see an example and a more detailed explanation in the
[docs](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/usage/custom-ca.md).
In the docs you can also find a guide on how to do CA rotation
([#499](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/499)).

### Service and Pod CIDR

The service and pod CIDR can now be configured in the environment / clusterctl.yaml file,
[#454](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/454).

The default values are:

| environment    | clusterctl.yaml | default          | meaning                                         |
|----------------|-----------------|------------------|-------------------------------------------------|
| `pod_cidr`     | `POD_CIDR`      | `192.168.0.0/16` | IPv4 address range (CIDR notation) for pods     |
| `service_cidr` | `SERVICE_CIDR`  | `10.96.0.0/12`   | IPv4 address range (CIDR notation) for services |

This change is not backwards compatible. Template and cluster defaults have to be updated.

As CAPO (CAPI OpenStack provider) does not support IPv6, yet, the IPv6 CIDR is not configurable.
The PR
[cluster-api-provider-openstack/#1557](https://github.com/kubernetes-sigs/cluster-api-provider-openstack/pull/1577)
aims to add first parts needed for IPv6 support you can check the current progress there.

### Harbor registry

* From [#445](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/445), it is possible to deploy
  Harbor into the workload cluster by using this project.
  For further details, check the
  [docs](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/usage/harbor.md).
* SCS community successfully deployed and uses Harbor registry at https://registry.scs.community/ using
  [k8s-harbor](https://github.com/SovereignCloudStack/k8s-harbor) project via the `k8s-cluster-api-provider`.
  The mentioned project has also been deployed in [dNation](https://dnation.cloud/) company
  at https://registry.dnation.cloud/.

### Gateway API

From [#503](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/503), Gateway API can be enabled with
the new configuration flag `DEPLOY_GATEWAY_API`. Unfortunately it breaks some sonobuoy conformance tests and is
considered a tech-preview only. This feature is disabled by default.

### Namespace separation for clusterctl in capi management server

When creating a new cluster, resources inside the capi management server are now created in a
separate namespace, [#481](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/481).
The namespace is named after the cluster name.
This allows utilizing the `clusterctl move` command and enable per cluster RBAC for the capi management server.

### New environment regiocloud

From [#476](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/476), a new environment `regiocloud`
from a new provider [https://regio-cloud.net/](https://regio-cloud.net/) which now supports SCS is supported.

### ETCD backup and defragmentation

The etcd defragmentation and backup process was enhanced
[#401](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/401)
to ensure responsiveness, stability, and safety of the
Kubernetes (k8s) control plane. The update introduces a script that strategically schedules defragmentation actions
across etcd nodes within the cluster. The script now intelligently skips defragmentation on non-leader nodes, clusters
with unhealthy members, or single-member clusters unless forced using optional arguments. The defragmentation sequence
is optimized by defragmentation of non-leader nodes first, followed by leadership change and defragmentation of the
selected
etcd member, and finally, backup and trim operations on the local (ex-leader) etcd member.

### Custom container registry in containerd

The Containerd container runtime interface (CRI) has been enhanced to provide configuration options for interacting
with public or private container registry hosts. These configuration options are detailed in
the [Containerd documentation](https://github.com/containerd/containerd/blob/main/docs/hosts.md). This feature enables
versatile use cases, such as configuring Containerd to utilize a custom CA certificate for interactions with container
registry hosts or specifying a container registry mirror to bypass restrictions, like DockerHub's pull rate limits. In
the SCS KaaS reference implementation, users can pass container registry host configuration files to configure
Containerd cluster-wide. The `containerd_registry_files` Terraform variable allows users to define additional registry
host configuration files and associated certificates, which will be copied to specific directories on each
cluster node.

The default configuration uses the `registry.scs.community` container registry as a public mirror of
DockerHub, addressing potential issues related to DockerHub's pull rate limits. This improvement helps ensure seamless
and efficient container registry interactions within SCS KaaS clusters. The default host config file used can be
found [here](/terraform/files/containerd/docker.io).

The feature has been implemented in [#432](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/432).
With this followup PRs:

- [#447](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/447)
  Add optional containerd registry config files
- [#477](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/477)
  Add migration steps for existing k8s clusters to adopt #432

### kube-apiserver resource limits

The kube-apiserver has memory and cpu resource limits set now such that it will not eat all
CPU and RAM on the control plane nodes, creating trouble for etcd or the CNI controller running there.
This will make the control-plane a bit more robust under extremely high load and cause it
to fail more gracefully if finally overwhelmed.
[#552](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/552)

### External network autodetection

Most clouds have exactly one external network for floating IP addresses.
In that case, it is autodetected and does not need to be set
by the `external` parameter in your environment file.
[#424](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/424)

### Zuul Nightly builds

The Zuul CI system is now used to run nightly CNCF conformance tests of the k8s-cluster-api-provider.
[#570](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/570)

## Minor improvements

- [#413](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/413)
  Make openstack instance create timeout configurable
- [#392](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/392)
  Comment on AZs, treat YQ3 as old yq.
    - This fix is later further rewritten for better support in #508
- [#422](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/422)
  Replace k8s registry locations
    - `k8s.gcr.io` -> `registry.k8s.io`
- [#453](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/453)
  Remove K8s v1.27.x from the techprev_versions list
- [#456](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/456)
  Add check to Makefile for `clouds.yaml` presence
- [#455](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/455)
  Rewrite documentation to be easier to get started.
- [#474](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/474)
  Gets variable username from .tfvars
- [#475](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/475)
  Add script that updates cluster files from R4 to R5
- [#507](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/507)
  Update management node root volume and FIP naming
- [#510](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/510)
  Check and fail if prefix is in use
- [#508](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/508)
  Detect `yq` being wrapper around `jq` and handle.
- [#536](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/536)
  Changed: replace usages of `apt` with `apt-get`
- [#523](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/523)
  Enhance `make create` to use actual commit for checkout
- [#557](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/557)
  Node images was moved to REGIO.cloud
- [#562](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/562)
  Enhance the logic to wait for k8s resources in create_cluster.sh
- [#551](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/551)
  Update delete_cluster.sh to more thoroughly delete all k8s resources
- [#560](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/560)
  Improve make purge
- [#566](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/566)
  Remove hardcoded ubuntu home folder

## Bug fixes

- [#416](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/416)
  Fix command not found in Makefile
- [#479](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/479)
  Fixes the handling of openstack auth_urls with implicit port
- [#489](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/489)
  Pass conformance tests with cilium
    - Only with Gateway API disabled
