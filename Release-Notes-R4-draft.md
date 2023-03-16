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
In addition, we have knowledge of deployments were > 100 clusters
are being managed using the capi-based SCS reference implementation
for k8s cluster management.

R4 was released on 2024-03-22.

## Updated software

### capi v1.3.5 and OpenStack capi provider 0.7.1

[Kubernetes Cluster API Provider](https://cluster-api.sigs.k8s.io/)
[OpenStack Provider for CAPI](https://cluster-api-openstack.sigs.k8s.io/)

### k8s versions (1.22 -- 1.26)

We test Kubernetes versions 1.22 -- 1.26 with the R4 Cluster API
solution. We had tested earlier versions (down to 1.18) successfully before,
and we don't expect them to break, but these are no longer supported
upstream and no fresh node images are provided by us.

Please note that k8s-v1.25 brought the removal of the deprecated Pod Security
Policies (PSPs) and brought  
[Pod Security Standards (PSS)](https://kubernetes.io/blog/2022/08/25/pod-security-admission-stable/) 
instead.

Release notes for upstream Kubernetes can be found [here](https://github.com/kubernetes/kubernetes/releases).
Please read the [API deprecation notes](https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-26)
when you move your workloads to the latest k8s versions.

### calico 3.25.x, cilium 1.13.x, helm 3.11.x, sonobuoy 0.56.x, k9s 0.26.x, kind 0.17.1, cert-manager 1.11.x, nginx-ingress 1.6.x

We regularly update to the latest stable versions and validate them.

In particular, cilium 1.13 has beta functionality implementing the upcoming k8s
gateway API; this can be tested for clusters that have `USE_CILIUM` set to `true`.

The latest nginx versions are also an option to test the upcoming gateway API.

For calico, cilium and flux2, we improved the version control; like for
cert-manager, nginx-ingress before, we pin a well-tested version for users
that choose `true`, but allow them overriding with a specific version by setting
the config parameter to `vX.Y.Z`. While these typically work, we do only validate
the default version.

## New features

### Restructuring our documentation

The README.md file previously was the one big file with a lot of information
on the SCS k8s-cluster-api-provider solution. This has been split up into several
more targeted documented, according to 
[our new standard structure](https://github.com/SovereignCloudStack/docs/blob/main/community/contribute/adding-docs-guide.md).
The documentation is best accessed via <https://docs.scs.community/>.

### Upgrade guide enhancements (#293) (#388)

See `doc/` directory.
<https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/Upgrade-Guide.md>

### Improved the maintenance and troubleshooting guide (#292) (#395)

Please check the doc directory.
<https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/Maintenance_and_Troubleshooting.md>

### Enabling the proxy protocol for nginx ingress and preliminary support for OVN LB (#325)

We have been able to address the issue that the proxy protocol breaks internal
connections to nginx. So we enable it by default now, when the nginx-ingress
service is deployed, allowing the nginx
service to see the real client IPs. We would like not to need this, but are
not fully there. For users that deploy services with `externalTrafficPolicy: local`,
it's worth reading the document at (doc/LoadBalancer-ExtTrafficLocal.md).

### Restrict access to the Kubernetes API (#246)

By setting `RESTRICT_KUBEAPI` to a list of IP ranges (CIDRs) when creating or updating the cluster,
access to the Kubernetes API will be restricted to the IP ranges listed in this parameter.
Note that access from the management host and from internal nodes will always be allowed,
as otherwise cluster operation would be seriously disrupted.

The default value (an empty list `[ ]`) will result in the traditional setting that
allows access from anywhere. Setting it to `[ "none" ]` will result in no access (beyond access
from internal nodes and the capi management server). Note that filtering for IP ranges from
the public internet is not
a silver bullet against connection attempts from evil attackers, as IP spoofing might be used,
so do not consider this the only line of defense to secure your cluster. Also be aware that in order
to allow for internal access, the IP address used for outgoing IP connections (with SNAT) is always
allowed, which typically means all VMs in this region of your cloud provider are allowed to connect.
A higher security setup might use a jumphost/bastion host to channel all API traffic through and
the local IP address of it could be configured in this setting. By changing the cluster-template,
one can even completely disable assigning a floating IP to the LoadBalancer in front of the kube-api
server.

When you use these controls and move your cluster-API objects to a new cluster, please ensure
that the new management cluster can access the kube-api from the to-be-managed cluster.
Otherwise no reconciliation can happen. (We consider creating helper scripts that do this
automatically if this turns out to be a popular things.) If you move to a cluster in the
same cloud, this typically does not need any special care, as the outgoing SNAT address
is already allowed.

<!--
### Capo instance create timeout (#383)

On OpenStack clouds that take a long time to create Virtual Machines, the default timeout for
new VMs to join the cluster may be insufficient. We have increased the default to 10mins and
allow users to further tweak it by setting `CAPO_INSTANCE_CREATE_TIMEOUT`.
-->

## Changed defaults/settings

As explained above, `NGINX_INGRESS_PROXY` now defaults to `true`.

## Important Bugfixes

### containers moved from k8s.gcr.io to registry.k8s.io (#321)

The move of the k8s registry from k8s.gcr.io to registry.k8s.io depending
on the exact version was not very well managed upstream and has caused a bit of
trouble to our users; we have mwanwhile adjusted all code to use the locations
depending on the version; for Mar 20, [yet another change](https://kubernetes.io/blog/2023/03/10/image-registry-redirect/)
has been announced that we may have to reflect in the code again. (If we are
lucky, there is a true redirect, so we don't need to adjust again.)

### etcd maintenance (#355, #384)

etcd storage can become fragmented over time, which causes the performance
to decrease and may even cause premature out-of-space conditions.
For this we had included a maintenance script that regularly defragments
the database. The code was inactive however due to an oversight.

This has been addressed; the defragmentation however only runs on the
non-leader members of the etcd cluster to avoid spurious temporary failures
and leader changes. This means that if your leader never changes, the leader
may never receive the defragmentation. This will improve in a future version.

Note that this also means that a single control-plane node cluster will
not receive the defragmentation either (and won't in the future); single-node
etcds are not made for long-term operation. As a workaround however, you can
scale up to three control-plane nodes over night from time to time.

## Upgrade/Migration notes

### Incompatible changes

## Removals and deprecations

Please note that the `ETCD_PRIO_BOOST` setting has been removed;
it was deprecated in R3 and had been ignored there already.
This should not cause any trouble.

## Known issues and limitations

Please read [Known issues and limitations](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/Release-Notes-R3.md#known-issues-and-limitations) from the R3 release notes; they still
apply.

### OpenStack API without properly TLS certificates (#372)

The automation assumes that the TLS certificates from the OpenStack API have
a trust chain anchored in a well-known CA. Let's Encrypt certificates do
fulfill this requirement. Using a custom CA is possible with OpenStack by
telling the clients which CAs to trust. K8s, CAPI, CAPO and OCCM also have
such capabilities, but the k8s-cluster-api-provider is currently not coded
such that the CA certificates would be automatically propagated and trusted.
While it is possible to get things working, it is manual work and we have not
yet documented it. We plan to improve this in the future. For now take our
advice to take care of properly signed certificates.

## Future roadmap

### Rate limiting 

To protect the etcd from overflowing, we have enabled compaction and defragmentation.
It is still possible to overwhelm etcd by firing k8s API calls at crazy rates.
It is best practice to enable rate-limiting at the kubeapi level, which we intend
to do after R4 (as opt-in feature -- it might become default in R4).

### Registry (#139)

We have a [harbor registry](https://registry.scs.community/) for hosting (and scanning)
image artifacts for the SCS community. This has been built using the
[SCS k8s-harbor](https://github.com/SovereignCloudStack/k8s-harbor) repository.
We have evaluated registry options by evaluating requirements and we intend to
provide an easy way to create registry instances along with SCS cluster management.

### Support for custom CA (#372)

Abovementioned limitation for OpenStack IaaS with custom CAs will be worked
upon to make this a scenario that works out-of-the-box.

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
These branches will receive updates until the end of October 2023.

## Contribution

We appreciate contribution to strategy and implemention, please join
our community -- or just leave input on the github issues and PRs.
Have a look at our [contribution invitation](https://scs.community/contribute/).
