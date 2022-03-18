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

### calico 3.22.x, cilium 1.11.x, helm 3.8.x, sononbouy 0.56.x, k9s 0.25.x

We regularly update to the latest stable versions.

### cert-manager 1.7.x, nginx-ingress 1.1.x

This also applies for the included standard cluster services.

## New features

### Independent Per-cluster settings

Previously, all clusters were supposed to mainly differ by the settings
in clusterctl.yaml. By creating directories for each cluster, using and
preserving separate cluster-templates becomes easy.

### Use artifacts from git on management node

Previously, to benefit from bug fixes and improvements in the
k8s-cluster-api-provider repository, one would have needed to deploy
a new management node including these improvements (or do some tedious
manual reconciliation). We now git clone the repository on the management
node and use it directly, so we can use `git pull` there to update.

### cilium

### cert-manager

### flux

### Anti-Affinity 

### etcd 

### MTU autodetection

### per-cluster app cred

We use an unrestricted application credential on the management node now,
so we can create per-cluster application credentials on it for better
isolation. Note that pre-cluster application credentials have not yet
been implemented.

## Important Bugfixes

### dns

### loadbalancer name conflict

### nginx-ingress health-monitor and proxy support

The upstream nginx-ingress controller deployment files uses an `externalTrafficPolicy: Local`
setting, which avoids unnecessary hops and also avoids forwarded requests that appear to
originate from the internal cluster. It however requires the L3 loadbalancer to use a
health-monitor. This was not explicitly set in the past, so we could end up 10 seconds on
the initial connection attempt (to a 3-node cluster). This has been addressed by
kustomization of the nginx-ingress deployment.
[#175](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/175).

Using the kustomization, the option `NGINX_INGRESS_PROXY` setting has also been introduced,
allowing the http/https services to receive the real IP address via the PROXY protocol.
It is enabled by default, as we expect most users to find this desirable.

## Upgrade/Migration notes

### Incompatible changes

* ANTIAFFINITY -> ANTI_AFFINITY
* deploy_metrics_service -> deploy_metrics
* dns_nameserver*s*

## Removals and deprecations

## Known issues and limitations

### --insecure metrics

### Incomplete change capabilties (no removal of services)

### 4 CNCF conformance fails with cilium

### Updatability

## Future roadmap

### helm charts

### harbor

### gitops

## Branch

We tag the R2 branch with the v3.0.0 tag and create a v3.0.x branches
for users that want to exclusively see bug and security fixes.
We will also create a v3.x branch for minor releases (which
however might never see anything beyond what we put into v3.0.x
if we don't create a minor release). 
If we decide to create a minor release, we would also create a 
v3.1.0 tag and a v3.1.x branch.

