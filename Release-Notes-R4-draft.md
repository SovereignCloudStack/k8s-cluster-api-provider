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

### capi v1.3.5 and openstack capi provider 0.7.1

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

### calico 3.25.x, cilium 1..x, helm 3.11.x, sonobuoy 0..x, k9s 0..x, kind 0.17.1

We regularly update to the latest stable versions.

### cert-manager 1.11.x, nginx-ingress 1.6.x

## New features

### Completed upgrade guide (#293)

See `doc/` directory.
<https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/Upgrade-Guide.md>

### Completed maintenance and troubleshooting guide (#292)

Please check the doc directory.
<https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/Maintenance_and_Troubleshooting.md>

### Restrict access to the Kubernetes API (#246)

By setting `RESTRICT_KUBEAPI` to a list of IP ranges (CIDRs) when creating or updating the cluster,
access to the Kubernetes API will be restricted to the IP ranges listed in this parameter.
Note that access from the management host and from internal nodes will always be allowed,
as otherwise cluster operation would be seriously disrupted.

The default value (an empty list `[ ]`) will result in the traditional setting that
allows access from anywhere. Setting it to `[ "none" ]` will result in no access (beyond internal
nodes and the management host). Note that filtering for IP ranges from the public internet is not
a silver bullet against connection attempts from evil attackers, as IP spoofing might be used,
so do not consider this the only line of defense to secure your cluster. Also be aware that in order
to allow for internal access, the IP address used for outgoing IP connections (with SNAT) is always
allowed, which means all VMs in this region of your cloud provider are allowed to connect.
A higher security setup might use a jumphost/bastion host to channel all API traffic through and
the local IP address of it could be configured in this setting. By changing the cluster-template,
one can even completely disable assigning a floating IP to the loadbalancer in front of the kube-api
server.

When you use these controls and move your cluster-API objects to a new cluster, please ensure
that the new management cluster can access the kube-api from the to-be-managed cluster.
Otherwise no reconciliation can happen. (We consider creating helper scripts that do this
automatically if this turns out to be a popular things.) If you move to a cluster in the
same cloud, this typically does not need any special care, as the outgoing SNAT address
is already allowed.

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
