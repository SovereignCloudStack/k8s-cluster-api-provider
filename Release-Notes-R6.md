# Release Notes of SCS k8s-capi-provider for R6

## Updated software

| Software       | Version  |
|----------------|----------|
| flux2          | v2.2.3   |
| sonobuoy       | v0.57.1  |
| Cilium         | v1.15.1  |
| Cilium cli     | v0.15.23 |
| Cilium Hubble  | v0.13.0  |
| cert-manager   | v1.14.2  |
| helm           | v3.14.1  |
| metrics-server | v0.7.0   |
| nginx-ingress  | v1.9.6   |
| k9s            | v0.31.9  |
| calico         | v3.27.2  |
| capi           | v1.6.2   |
| capo           | v0.9.0   |

### k8s versions (1.25 -- 1.28)

We test Kubernetes versions 1.25 -- 1.28 with the R6 Cluster API
solution. We had tested earlier versions (down to 1.21) successfully before,
and we don't expect them to break, but these are no longer supported
upstream and no fresh node images are provided by us.

Release notes for upstream Kubernetes can be found [here](https://github.com/kubernetes/kubernetes/releases).
Please read the [API deprecation notes](https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-29)
when you move your workloads to the latest k8s versions.

Kubernetes v1.29 can be deployed as a technical preview for now, but
we expect that it will be stabilized soon.

## New features

### OpenTofu

In R5 we protected users from accidentally using unfree BSL licensed code by terraform version constraint.
Now, in [#606](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/606), we replaced Terraform
with [OpenTofu](https://opentofu.org/),
an open-source, community-driven IaC tool. Users don't have to worry anymore.

### ClusterClass

From [#600](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/600), this repository uses CAPI
[ClusterClass](https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-class/) feature for the creation of
clusters, see k8s [blog](https://kubernetes.io/blog/2021/10/08/capi-clusterclass-and-managed-topologies/) for overview.
This feature is also used in the SCS [Cluster Stacks](https://github.com/SovereignCloudStack/cluster-stacks) - KaaS
reference implementation v2.

### Proxy

[#418](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/418) is about support for corporate proxy
in the Kubernetes clusters. In R6, users are able to specify e.g. `http_proxy = "http://10.10.10.10:3128"`
and this proxy setting will be propagated to the management host as well as on the worker and control plane nodes,
see [#620](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/620)
and [#645](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/645) for details.
There is also a `no_proxy` setting for configuring exceptions,
[#651](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/651).

### OVN LB

Starting from R4, it's possible to configure the LoadBalancer in front of ingress-nginx to
utilize the OVN provider instead of the default Amphora provider.
However, it's important to note that this capability was introduced as a tech preview feature
and was not recommended for production use.
In R6 [#687](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/687),
after all upstream issues were resolved, we removed the tech preview flag and carefully tested it with success.
OVN LoadBalancer can be enabled by setting `use_ovn_lb_provider = "true"` or `use_ovn_lb_provider = "auto"`.
In the upcoming release, we expect it will be the default configuration.

### Renovate

Automated dependency updates and [renovate bot](https://docs.renovatebot.com/)
are part of this repository from [#596](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/596)
where config for CAPI and CAPO was added.
Later it was extended for calico in [#622](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/622),
terraform-provider-openstack in [#633](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/633)
and for k9s in [#629](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/629).
More will come in the future, see [#577](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/577).

### Restrict access to the management server

From [#599](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/599),
it's now possible to restrict port 22 SSH access to the management server using a whitelist of CIDRs.
By default, there are no restrictions, as indicated by `restrict_mgmt_server = ["0.0.0.0/0"]`.

### Configurable network cidr fot the management server

Management server was using hardcoded `"10.0.0.0/24"` network until [#655](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/655).
User can now specify it, e.g. `mgmt_cidr = "10.0.0.0/24"` and `mgmt_ip_range = {start:"10.0.0.11", end:"10.0.0.254"}`.

### Parallel execution of scripts

Have you ever thought about whether it is possible to delete one cluster and create another at the same time?
It is now possible thanks to [#583](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/583).

## Minor improvements

- [#617](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/617)
  Install kubectx on management node
- [#618](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/618)
  Install kube_ps1 on management node
- [#584](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/584)
  Add option to specify external net via ID
- [#614](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/614)
  Add an Ansible lint GitHub action and supply the required code modifications
- [#616](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/616)
  Add "stale" GitHub Action
- [#610](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/610)
  Support custom zuul configs
- [#682](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/682)
  Remove unused OPENSTACK_CONTROL_PLANE_IP parameter
- [#624](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/624)
  Preserves (possible) additional docker-daemon settings
- [#643](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/643)
  Drop k8s <= v1.20.x

## Bug fixes

- [#579](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/579)
  Fix curl warning
- [#608](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/608)
  Update terraform cache directory for providers
- [#621](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/621)
  Add checkout to PR branch into e2e tests
- [#639](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/639)
  Delete "*sets" before k8s pods to ensure we enumerate all of them
- [#625](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/625)
  Fix kubeapi cidr restrictions
- [#656](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/656)
  Fix metrics server upgrade
- [#689](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/689)
  Fix CLUSTER_NAME propagation for create_appcred.sh
