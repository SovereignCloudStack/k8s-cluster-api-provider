# Release Notes for SCS k8s-capi-provider for R3

k8s-cluster-api-provider was provided with R1 of Sovereign
Cloud Stack and has since seen major updates in R2 and was
hardened for production use during the R3 development phase.

The SCS cluster management solution was heavily used by the
development and integration work in the Gaia-X Federation 
Services [GXFS](https://gxfs.eu/) project; the resulting
Open Source Software nicely combines with
[Sovereign Cloud Stack](https://scs.community/) to form a
rather complete set of tools that can be used to provide
Gaia-X conforming services on top of sovereign infrastructure.

R3 was released on 2022-09-21.

## Updated software

### capi v1.2.x and openstack capi provider 0.6.x

After reaching the 1.0.x (`v1beta1`) status with R2, we have seen
further improvements in the 
[Kubernetes Cluster API Provider]()
and the
[OpenStack Provider for CAPI]()
especially with respect to operational stability
in situations with errors.

### k8s versions (1.21 -- 1.25)

We test the kubernetes versions 1.21 -- 1.25 with the R3 cluster-api
solution. We had tested earlier versions (down to 1.18) successfully before,
and we don't expect them to break.

Please note that k8s-v1.25 brings the removal of the deprecated Pod Security
Policies (PSPs). Instead 
[Pod Security Standards (PSS)](https://kubernetes.io/blog/2022/08/25/pod-security-admission-stable/) 
can be enforced by the Pod Security Admission controller. If you heavily
relied on PSPs before, migration can be non-trivial though, as can be read
in the [blog article](https://www.giantswarm.io/blog/giant-swarms-farewell-to-psp)
from our friends at GiantSwarm. So please consider this when going to 1.25.

### calico 3.24.x, cilium 1.12.x, helm 3.8.x, sonobuoy 0.56.x, k9s 0.26.x, kind 0.14.x

We regularly update to the latest stable versions.

### cert-manager 1.9.x, nginx-ingress 1.3.0

This also applies for the included standard cluster services.
Note that we intentionally used v1.3.0 instead of the latest v1.3.1 for
nginx-ingress, as it represents the version that allows you to cleanly
migrate from older controllers.

It should be noted that the users can freely chose and override the versions;
we however don't test all combinations and instead default to the ones we
tested intesively.

## New features

### Per-cluster app cred (#177, #226, #232, #272)

This was prepared during the R2 development and finalized for R3:
We use an unrestricted application credential on the management node;
for each cluster a distinct restricted application credential (an application
credential that can not create any further credentials) is created now.
This is useful in case the application credential needs to be withdrawn
(e.g. because it was leaked) -- in that case only the one cluster using
it will be affected. So this helps the operations teams to better isolate
many clusters in their handling.

### Simplified (rolling) node upgrades (#223)

clusterctl offers the ability to upgrade to a newer k8s version
or doing other changes to the k8s control-plane and worker nodes
(such as e.g. changing the flavor type). It orchestrates a nice
rolling upgrade, avoiding downtime, for these cases (assuming you
have not created single-node control-planes).

It was previously a bit tedious to perform, as it required changing
the names of the machine templates in the `cluster-template.yaml`.
This is no longer the case: Just increase the generation counters
of `CONTROL_PLANE_MACHINE_GEN` and `WORKER_MACHINE_GEN` in your
settings file (`clusterctl.yaml`) and call `create_cluster.sh` again
to invoke the rolling upgrade.

### Background etcd maintenance tasks (#282)

etcd stores the historical states of its keys and values.
This can lead to a rather large database, slowing down etcd or -- in
extreme cases -- leading to exhausting the allocated space of 2GiB.

We now limit the stored old states to compact the database and have also
add a nightly maintenance job that defragments the database to release
unused space. We also store a snapshot of the database state to help
with recovery in case things go terribly wrong. (No, we have not observed
this.)

### testcluster name adjustment (#264)

When deploying a new management host, users can choose to directly
create a testcluster. This was typically used for CI tests and the
cluster was hardcoded to be called `testcluster`.
However, some users might want to use such a cluster for other purpose
and dislike the chosen name -- it is thus adjustable now.

### New upgrade guide (#)

### New maintenance and troubleshooting guide (#)

## Changed defaults/settings

### etcd heartbeart interval and prio boost (#279, #282)

Previously, we required the user to set `ETCD_PRIO_BOOST` to `true` in
order to work with longer heartbeat intervals and increase the priority
for IO and CPU of the etcd process. This is now hardcoded, as there are
no downsides in our usage scenario. So we unconditonally use a
`heartbeat_interval` of 250ms and 10 beats as leader election timeout.

Please note that the other etcd tweaking, `ETCD_UNSAFE_FS` remains a
setting that users need to consider and that continues to default
to `false`. `false` is the best setting for single-control-plane-node
clusters and clusters that have control-plane-nodes with fast
(SSD/NVMe) local storage, which is the recommended configuration.
However, such flavors are not available on all clouds; if you build
a multi-control-plane-node cluster that uses ceph-backed storage
for these nodes, you need this tweak to avoid spurious leader changes.
In a multi-controller setup, the risk of inconsistent etcd database
state on a crash is not relevant unless all control-plane-nodes
crash. (The anti-affinity rules make this very unlikely.)

### OpenStack resource naming (#262)

The names of the IaaS resources managed can be tweaked; whereever
possible, we use `$PREFIX-$CLUSTER_NAME-$RESOURCEID` naming now.
It should be noted that this does not apply everywhere; some code
in the OpenStack Cluster API Provider and the OpenStack Cloud
Controller Manager does not allow us to fully control the names,
so you will find `kube-service` and `k8s-cluster-api` and `default`
pieces in the IaaS names. This will require some upstream work to
get a consistently clean state.

### License is Apache-2.0 now (#242)

A number of the scripts used SCS/k8s-cluster-api-provider
was released under the CC-BY-SA-4.0 license before. Other pieces
in the repository were under the Apache-2.0 license which is very
popular in the modern Cloud and CNCF world. This made license
compliance a bit tricky for consumers of the code, so we
relicensed all code in this repository to be under Apache-2.0.

## Important Bugfixes

### Port cleanup (#219)

Occasionally, the infrastructure may not be succssful in creating
servers or a loadbalancer, e.g. due to exhausted quota or such.
In that case, the unsuccessful cluster should be deleted again,
so everything gets cleaned up.
We have observed several occasions where capo was unsuccessful
in doing a complete cleanup, as the port (virtual network interface)
for the server was left over, blocking the deletion of security
groups and networks.

The cleanup scripts now check for this situation and clean up the
port if needed.

## Upgrade/Migration notes

### Incompatible changes

No incompatible/breaking changes were introduced with R3.
Please see the new Upgrading Guide for more information how to migrate
your management host and workload clusters from R2 to R3.

## Removals and deprecations

None.

Please note that the `ETCD_PRIO_BOOST` setting will be removed;
it is ignored already. However, this won't break anything.

## Known issues and limitations

### Clusters need maintenance

Like with other kubeadm k8s clusters, there is some maintenance required for the
cluster operators. The client certificates used by the various k8s components
have a 1-year lifetime. We have ensured that certificate rotation is enabled;
upon an update (e.g. doing a patchlevel k8s version upgrade), the rotation
will happen. However, if left alone for more than a year, the certificates
will expire and the cluster will need some loving care then to be revived
with `kubeadm certs rotate` on the control-plane nodes. Please see the
Maintenance and Troubleshooting Guide for more details.

We consider adding a job on the control-nodes to avoid this in a future release.

Please be aware that the CA generated by k8s expires after 10 years;
if you intend to run clusters for longer, please be aware of this. An external
CA might be a good idea (see next paragraph).

### metrics with --kubelet-insecure-tls (#148)

Like most kubeadm based setups, we used --kubelet-insecure-tls for the metric
service to be allowed to talk to kubelets to retrieve metrics. This can be improved
by using a CA-signed server cert for the kubelets.
We have some thoughts on using a CA external to the control-plane nodes and
have thus not addressed this yet.

### No removal of services from `create_cluster.sh` (#137)

You can call `create_cluster.sh` many times to apply changes to your
workload cluster -- it is idempotent and does not do any changes if your config
is unchanged. If you enabled extra services, these will get deployed.
It currently however does not remove any of the deployed
standard services that you might have had enabled before and now set to
`false`. (We will require a `--force-remove` option or so to ensure that
users are aware of the risks.) This is unchanged from R2.

### No support for changing b/w calico and cilium (#131)

Switching between the two CNI alternatives is currently not facilitated
by the `create_cluster.sh` script. It can be done by removing the
current CNI manually (delete the deployment yaml or cilium uninstall)
and then calling `create_cluster.sh`. However, this has the potential
to disrupt the workloads in your workload clusters.
This is unchanged from R2.

### Four CNCF conformance test fails with cilium (#144)

We want to understand whether these four failures could be avoided by tweaking
the configuration or whether those are commonly ignored. The investigation
still has to be done.
This is unchanged from R2.

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

We tag the R3 branch with the `v4.0.0` tag and create a 
`maintained/v4.0.x` branch for users that want to exclusively see bug
and security fixes. We will also create a `maintained/v4.x` branch for
minor releases (which however might never see anything beyond what
we put into v4.0.x if we don't create a minor release). 
If we decide to create a minor release, we would also create a 
v4.1.0 tag and a v4.1.x branch.
These branches will receive updates until the end of April 2023.

## Contribution

We appreciate contribution to strategy and implemention, please join
our community -- or just leave input on the github issues and PRs.
Have a look at our [contribution invitation](https://scs.community/contribute/).
