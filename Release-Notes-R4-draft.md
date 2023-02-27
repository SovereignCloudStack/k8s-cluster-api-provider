# Release Notes of SCS k8s-capi-provider for R4

** NOTE: THIS IS A DRAFT DOCUMENT TO COLLECT INPUT UNTIL THE RELEASE DATE **

k8s-cluster-api-provider was provided with Release 1 (R1) of Sovereign
Cloud Stack and has since seen major updates in R2, was
hardened for production use during the R3 development phase
and received a lot of real-world exposure since:

The SCS cluster management solution is heavily used by the
development and integration work in the [Gaia-X Federation 
Services (GXFS)](https://gxfs.eu/) project; the resulting
Open Source Software nicely combines with
[Sovereign Cloud Stack](https://scs.community/) to form a
rather complete set of tools that can be used to provide
Gaia-X conforming services on top of sovereign infrastructure.

R4 was released on 2024-03-22.

## Updated software

### capi v1.. and openstack capi provider 0..

[Kubernetes Cluster API Provider](https://cluster-api.sigs.k8s.io/)
[OpenStack Provider for CAPI](https://cluster-api-openstack.sigs.k8s.io/)

### k8s versions (1.22 -- 1.26)

We test the Kubernetes versions 1.22 -- 1.26 with the R4 Cluster API
solution. We had tested earlier versions (down to 1.18) successfully before,
and we don't expect them to break, but these are no longer supported
upstream and no fresh node images are provided by us.

Please note that k8s-v1.25 brought the removal of the deprecated Pod Security
Policies (PSPs) and brought  
[Pod Security Standards (PSS)](https://kubernetes.io/blog/2022/08/25/pod-security-admission-stable/) 
instead.

k8s-v1.26 is not officially supported by capi yet; it has survived our
testing with the CNCF testsuite, rolling upgrades and `clusterctl move`s though,
so we do allow the deployment using an override parameter.

### calico 3..x, cilium 1..x, helm 3.11.x, sonobuoy 0..x, k9s 0..x, kind 0.17.1

We regularly update to the latest stable versions.

### cert-manager 1..x, nginx-ingress 1..0

## New features

### Supporting proxy protocal and the OVN provider for the Octavia loadbalancer

The default CNCF nginx ingress controller deployment chart use `externalTrafficPolicy: local`.
This disables the normal `kube-proxy` forwarding connections to the right node.
In an ideal world, this saves a hop and allows the service to see the real client IP.
For this to work, a few further conditions must be true:
* A load-balancer must be in front of the service forwarding the traffic to the correct
  (worker) nodes. This requires some integration between k8s and the load-balancer or
  a load-balancer health monitor to detect which nodes respond.
* A load-balancer that terminates the TCP connection (L4 loadbalancer) and then opens the
  connection to the backend member will occlude the real client IP. We thus need to
  either have L3 load-balancing to expose the client IP or create a side-channel for
  the load-balancer to share this information with the backend service.

For the deployment of the nginx ingress controller with the cluster
(`DEPLOY_NGINX_INGRESS=true`), we had always enabled the OpenStack's load-balancer's
health-monitor using a special annotation to make the traffic flow. There also has
been the option to enable the proxy protocol to enable the load-balancer to
forward information on the real client IP to the nginx service; however the
proxy protocol was disabled by default due to fact that it broke local traffic
to the load-balancer. The breakage has been addressed, so we could change the
default.

Using the proxy protocol is only our second best choice:
* The solution is application specific; when you deploy your own services,
  you have extra work to add the correct custom annotations or may not even
  have the ability to see the real client IPs.
* The custom header is not particularly nice design.

Our best option would be to have a load-balancer that works at layer 3 of the
network. Turns out that such a thing exists in SCS IaaS deployments that use
OVN for networking. We would still need the health-monitor, but not the
proxy protcol. To use the OVN loadbalancer, set `USE_OVN_LB_PROVIDER` to `auto`.
This will use it if your cloud support it (and then also enable the health-monitor
by default). On these clouds, serivces with `externalTrafficPolicy: local` should
work like a charm. On all others, they won't.

We still had to set the default to `False`: There currently is an upstream bug
that prevents the health-monitor with OVN provider load-balancers to be
effective for accesses via the floating-IP address. Until this is resolved,
we can not get everything to work. We are looking into the upstream issue
and hope to contribute and backport a fix before R5.

### Completed upgrade guide (#293)

See `doc/` directory.
<https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/Upgrade-Guide.md>

### Completed maintenance and troubleshooting guide (#292)

Please check the doc directory.
<https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/Maintenance_and_Troubleshooting.md>

## Changed defaults/settings

## Important Bugfixes

### containers moved from k8s.gcr.io to registry.k8s.io (#321)
....

## Upgrade/Migration notes

### Incompatible changes

## Removals and deprecations

Please note that the `ETCD_PRIO_BOOST` setting has been removed;
it was deprecated in R3 and had been ignored there already.
No breakage.

## Known issues and limitations

Please read [Known issues and limitations](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/Release-Notes-R3.md#known-issues-and-limitations) from the R3 release notes; they still
apply.

## Future roadmap

### Rate limiting 

To protect the etcd from overflowing, we have enabled compaction and defragmentation.
It is still possible to overwhelm etcd by firing k8s API calls at crazy rates.
It is best practice to enable rate-limiting at the kubeapi level, which we intend
to do after R3 (as opt-in feature -- it might become default in R4).

### Access controls

By default, the kubeapi server exposes the k8s API to the public internet via a
load balancer. While this interface is well protected, it is still a level of
exposure that security-aware people tend to dislike. So we plan to allow limiting
the access to be only available internally (i.e. from the cluster itself,
the management host and an optional bastion host) plus selected IP ranges that
the user specifies. This will be an opt-in feature and we plan to deliver it
prior to R4.

### harbor (#139)

We have a harbor registry for hosting (and scanning) image artifacts
for the SCS community. This has been built using the 
[SCS k8s-harbor](https://github.com/SovereignCloudStack/k8s-harbor) repository.
We intend to provide an easy way to create ow harbor instances along with
SCS cluster management.

### Cluster standardization

Most users of the cluster-API based cluster management will only ever need
to touch the `clusterctl.yaml` settings file. Our intention is thus to
standardize cluster-management on that level: Have a simple yaml file
that describes the wanted cluster state. Exposing all the power of
cluster-API behind it is optional and not required for SCS conformance.

The settings are currently processed with the cluster-template by clusterctl
and then submitted to the k8s management cluster. In our to be standardized
approach, we will have a few cluster templates; the simple one that is
already used today and more complex ones that e.g. support multiple machine
deployments. The settings will be made cloud-provider independent; we intend
to allow non-OpenStack clouds and even non-CAPI implementations with respects
to SCS standards conformance. Obviously, few pieces of the reference implementation
will work as is, but this should not affect the user. The cluster-templates
obviously will be provider dependent as well, but its behavior will be
standardized.

To allow for templating, we may go beyond the clusterctl capabilities
and use helm or helmfile for this. This may also allow us to incorporate
some of the nice work from the
[capi-helm-charts](https://github.com/stackhpc/capi-helm-charts) from
[StackHPC](https://stackhpc.com).

We are currently pondering whether we can expose the k8s management cluster
kube API to users in a multi-tenant scenario. We certainly would need some
work with namespaces, kata containers and such to make it safe in a
multi-tenant scenario. Right now, we may opt to put a REST interface
in front of the kubeAPI to better shield it.

We had some thoughts to allow gitops style management
(see [Docs/#47](https://github.com/SovereignCloudStack/Docs/pull/47))
where cluster settings
would be automatically fed from a git repository; we still have this vision,
but after numerous discussions came to the conclusion that this will be
an opt-in feature.

## Conformance

With Calico CNI, the k8s clusters created with our SCS cluster-API based
cluster management solution pass the CNCF conformance tests as run by
[sonobuoy](https://sonobuoy.io/).

With the gitops approach, we intend to standardize the
`clusterctl.yaml` settings to allow a straightforward approach to
declarative cluster management. This is intended for R4 (3/2023).

## Branching

We tag the R4 branch with the `v5.0.0` tag and create a 
`maintained/v5.0.x` branch for users that want to exclusively see bug
and security fixes. We will also create a `maintained/v5.x` branch for
minor releases (which however might never see anything beyond what
we put into v5.0.x if we don't create a minor release). 
If we decide to create a minor release, we would also create a 
v5.1.0 tag and a v5.1.x branch.
These branches will receive updates until the end of April 2023.

## Contribution

We appreciate contribution to strategy and implemention, please join
our community -- or just leave input on the github issues and PRs.
Have a look at our [contribution invitation](https://scs.community/contribute/).
