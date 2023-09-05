# Release Notes of SCS k8s-capi-provider for R5

## Updated software

### terraform v1.4.6

Terraform used for creation of capi management server, security groups for cluster,
executing of bootstrap script, etc. has been updated and validated.

TODO: mention also #515 Require terraform version < 1.6.0

### flux2 0.41.x

### sonobuoy 0.56.x

### cilium 1.14.0

- Sonobuoy v0.56.17 adds support for the latest k8s versions even for k8s 1.27.

### cert-manager 1.12.x

### kind 0.18.0

### helm 3.12.x

### metrics-server 0.6.4

### nginx-ingress 1.8.x

- We removed support for older k8s versions <= 1.19. Ingress-nginx 1.8.1 supports k8s version >= 1.24.
  See also
  ingress-nginx [supported versions table](https://github.com/kubernetes/ingress-nginx#supported-versions-table).

### k9s 0.27.x

- In the previous releases, the latest version was used. Now, it is pinned.

### calico 3.26.x

## New features

### Ubuntu 22.04

We upgraded capi management server to the 22.04 LTS release in the R4.
Now [#434](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/434),
we upgraded also images which are used for the k8s control plane and worker nodes.
Before the upgrade, testing [#409](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/409)
was done and revealed two additional problems.
Both problems were investigated, fixes were introduced to the upstream
and were successfully
merged [kubernetes-sigs/image-builder/#1146](https://github.com/kubernetes-sigs/image-builder/pull/1146),
[kubernetes-sigs/image-builder/#1182](https://github.com/kubernetes-sigs/image-builder/pull/1182).
The Ubuntu 22.04 LTS node images are available starting from k8s version 1.25.11, 1.26.6 and 1.27.3.

### Storage snapshots

The CSI driver deployed with SCS (in R4) did not have the needed snapshot-controller
container ([#408](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/408))
deployed while it already did deploy the needed snapshot CRDs.
The missing container has been added
now ([#415](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/415))
and snapshot functionality is validated using the check-csi CNCF/sonobuoy test.

(This fix was also backported to the maintained R4 (v5.x and v5.0.x) branches.)

### Cilium is the default CNI now
We have decided to use cilium as default CNI, [#431](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/431).
You can still override this and set `USE_CILIUM="false"` if you prefer Calico.

### Support for diskless flavors

The SCS [flavor spec v3](https://github.com/SovereignCloudStack/standards/blob/main/Standards/scs-0100-v3-flavor-naming.md)
makes the flavors with root disks only recommended (except for the two new SSD flavors).
The used `cluster-template.yaml` now is dynamically patched to allocate a root disk
as needed when diskless flavors are being used, [#424](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/424).

This change requires installation of `jq`.

(This fix is backported to the maintained R4 branch v5.x.)

### Custom CA
From [#460](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/460), the k8s-cluster-api-provider supports situation
when communication with OpenStack API is protected by the certificate issued by custom or private CA.
All you have to do is provide `cacert` option in your clouds.yaml configuration file. Cacert will be copied
to the management and workload cluster so provide only necessary certificates in that file.
You can see an example and a more detailed explanation in the [docs](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/usage/custom-ca.md).

TODO: mention also CA rotation docs - #499 Ca rotation

### Service and Pod CIDR
The service and pod CIDR can now be configured in the environment / clusterctl.yaml file, [#454](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/454).
The default values are:

| environment    | clusterctl.yaml | default          | meaning                                         |
|----------------|-----------------|------------------|-------------------------------------------------|
| `pod_cidr`     | `POD_CIDR`      | `192.168.0.0/16` | IPv4 address range (CIDR notation) for pods     |
| `service_cidr` | `SERVICE_CIDR`  | `10.96.0.0/12`   | IPv4 address range (CIDR notation) for services |

This change is not backwards compatible. Template and cluster defaults have to be updated.

As CAPO (CAPI OpenStack provider) does not support IPv6 yet, the IPv6 CIDR is not configurable.
The PR
[cluster-api-provider-openstack/#1557](https://github.com/kubernetes-sigs/cluster-api-provider-openstack/pull/1577)
aims to add first parts needed for IPv6 support you can check the current progress there.

### Harbor registry

SCS community successfully deployed and uses Harbor registry at https://registry.scs.community/ using
[k8s-harbor](https://github.com/SovereignCloudStack/k8s-harbor) project. The mentioned project has also been
deployed in [dNation](https://dnation.cloud/) company at https://registry.dnation.cloud/.
From [#445](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/445), it is possible to deploy
Harbor in a similar way into the workload cluster by using this project. For further details
check the [docs](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/usage/harbor.md).

### Gateway API
From [#503](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/503), Gateway API can be enabled with the new configuration flag `DEPLOY_GATEWAY_API`. Unfortunately it breaks some sonobuoy conformance tests and is considered a tech-preview only. This feature is disabled by default.

### Namespace separation for clusterctl in capi management server

When creating a new cluster, resources inside the capi management server are now created in a
separate namespace, [#481](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/481). The namespace is named after the cluster name. This allow to utilize the
`clusterctl move` command and enable per cluster RBAC for the capi management server. 

# TODO

## New features
- #401 Update etcd defrag and backup
- #432 Add option to use custom container registry in containerd
  - #447 Add optional containerd registry config files
  - #452 Fix default cluster directory ~/cluster-defaults cp command
  - #472 Fix configure_containerd.sh script idempotency
  - #477 Add migration steps for existing k8s clusters to adopt #432
- #476 Adds new environment regiocloud
- update Gateway API line - (validate this with Roman)
- #509 Feat/support debian12

## Updated software
- #427 Update CAPI to v1.3.8 and CAPO to 0.7.3.
- #428 Update to latest k8s and latest occm versions.
- merge sonobuoy lines

## Minor improvements
- #413 Make openstack instance create timeout configurable
- #392 Comment on AZs, treat YQ3 as old yq.
- #422 Replace k8s registry locations (#412)
- #453 Remove K8s v1.27.x from the techprev_versions list
- #456 Add check to Makefile for clouds.yaml presence
- #455 Rewrite documentation to be easier to get started.
- #474 Gets variable username from .tfvars
- #475 Add script that updates cluster files from R4 to R5
- #507 Update management node root volume and FIP naming #495
- #510 Check and fail if prefix is in use
- #508 Detect yq being wrapper around jq and handle.
- #536 Changed: replace usages of apt with apt-get
- #523 Enhance make create to use actual commit for checkout #522

## Bug fixes
- #416 Fix command not found in Makefile  - validate with Roman
- #479 Fixes the handling of openstack auth_urls with implicit port
- #489 Pass conformance tests with cilium
