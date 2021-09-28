# Release Notes for k8s-capi-provider for R1

k8s-cluster-api-provider was provided as technical preview in R0
and has seen major work to make it ready for productive use in T1.

Following are the highlights of changes done for R1.

## capi v0.4 and openstack capi provider 0.4

The [Kubernetes cluster API](https://cluster-api.sigs.k8s.io/) has been
updated to [version alpha 4] (https://github.com/kubernetes-sigs/cluster-api) 
(aka 0.4), which came with changes to the templates.
The SIG expects this format to now be close to what a beta and stable version
will provide. We refer to the [upstream release notes](https://github.com/kubernetes-sigs/cluster-api/releases)
for more details.

Likewise the [Cluster API provider OpenStack](https://github.com/kubernetes-sigs/cluster-api-provider-openstack)
has been updated to the matching 0.4 version. Release Notes are available
[here](https://github.com/kubernetes-sigs/cluster-api-provider-openstack/releases).

## k8s version 1.21.4

We are actually flexible to create clusters with various k8s versions -- we have
validated 1.19.14, 1.20.10 and 1.21.4 and are defaulting to the
[v1.21.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.21.4) version.

## kind update

We have upgraded [kind](https://github.com/kubernetes-sigs/kind) to
[v0.11.1](https://github.com/kubernetes-sigs/kind/releases/tag/v0.11.1),
which uses k8s-v1.21.1. This way we have very similar k8s versions for our
workload clusters as on the management node. This also required to inject
a sysctl to increase the max conntrack connections.

## Multi-cluster management scripts

The scripts have been made more modular and have gained the ability to cleanly
handle many clusters from the same management node. Please refer to the main
(README.md) file for an overview over the scripts. Compared to R0, some of the
scripts have been renamed (e.g. ``deploy_cluster.sh`` -> ``create_cluster.sh``
and some have been added (e.g. ``delete_cluster.sh``).

## Cluster services

The OpenStack integration and the Cinder CSI can optionally be deployed from upstream
git instead of the included copies, see parameters ``DEPLOY_K8S_OPENSTACK_GIT``
and ``DEPLOY_K8S_CINDERCSI_GIT``. The cinder CSI deployment now does register
the snapshotclasses API extension, so the snapshotting service does no longer
error out. Both OpenStack and Cinder CSI integration are always enabled when
creating a cluster with ``create_cluster.sh`` -- this has not changed from
R0.

We optionally deploy the k8s metrics service and the deployment is enabled
by default. It can be controlled by ``DEPLOY_METRICS``.

The NGINX ingress controller was also added, also enabled by default and
controlled by ``DEPLOY_NGINX_INGRESS`.

## CNI (Calico)

We have not yet switched away from Calico as CNI, as it has been working
fine for us thus far and we have not yet found the time to carefully analyze
potential advantages of Cilium and to carefully validate it.
This is still on our TODO list.

## Dropped docker

docker used to be installed on the control and worker nodes.
This is no longer the case, the kubelets now talk directly to containerd
there. We inject the MTU size for the cluster now directly when deploying
calico CNI -- this was previously handled via docker.

Note that docker is still used on the management node where kind gets
deployed. However, the deprecated docker-shim is not used here, so we
don't inject discontinued technology here.

## MTU configurable

The MTU for the container clusters can be set from the ``tfvars`` config
file now and will be applied on both the management node as well as the
created clusters. We default to 1400, which works fine on all environments
that we use for testing.

## node_cidr configurable

The VMs for the k8s cluster now have a configurable CIDR.
We default to 10.8.0.0/20 now, supporting 4k nodes.

## Application Credential

Rather than copying a clouds.yaml and cloud.conf on the management node
that contains a copy of the user's original auth data which can vary a lot,
we now create a v3 application credential, which allows us to work with
the same credential setup always and also allows for revocation in case
of leakages. See [README.md](README.md) for more information.

## No ./clouds.yaml copy needed

You no longer need to create a (stripped down) copy of clouds.yaml and
secure.yaml in the terraform directory. If you have these files at their
standard place ``~/.config/openstack/``, the terraform logic will now
find what it needs to extract from there.

## Speed up

The process of setting up the management node has been streamlined.
As the image registration can take a while, we do it in the background
now. (There is also an option to convert a qcow2 image to a raw image
before registration, as the performance of these is better when ceph
clusters are used as backing store due to advantageous copy-on-write
capabilities.) While the cloud chews on the image registration we further
set up the local k8s cluster (kind) and only wait for the image to become
ready before the preparatory scripts completes.

The image stays registered, so we can reuse it from within the same
project. The image carries the major version number from k8s (e.g. 1.21),
so several "major" versions can coexist. Remove it to get a freshly
downloaded one registered on the next deployment of a management node
(or call ``upload_capi_image.sh`` manually).

The registered CAPI image also sets the standard image metadata
according to SCS specs.

## Cleaning up

Creating lots of test clusters, robust clean up methods are reqired.
The cleanup handling has seen a lot of work, making sure we don't
accidentally leave OpenStack resources around. ``make clean`` does now
remove created VMs, networks, load balancers, persistent volumes for
the workload clusters before it asks terraform to clean up the
ressources associated with the management node. The ``fullclean``
target does it on OpenStack in case ``clean`` fails due to k8s capi
not being in a good state any more.

## Configurable namespace

A different namespace can be chosen from "default". Note that this
does not have a lot of consequences, as the scripts don't deploy
anything to the default namespace by default ...

## Tools

calicoctl, a newer k9s, helm and sonobuoy are installed into
``/usr/local/bin`` for the user's convenience.

## clouds.yaml moved

The clouds.yaml is no longer deployed to ``~`` on the mangement
node, but to ``~/.config/openstack/``, where openstack CLI will
always find it (irrespective of the current directory). The cloud.conf
file that is fed as secret to the capi cluster still lives in ``~``.
The clouds.yaml that ends up as secret as well is constructed on
the fly (with a unneeded ``project_id`` added in), encoded and
fed to the capi cluster -- this file is not stored on the file system.

## SCS flavor name defaults

We are using defaults for the flavor names and image names that follow
the SCS standards, so you don't need to touch them on a fully SCS
compliant cloud. The flavors now can be chosen separately for the
management node, the controller nodes and the worker nodes.

## Testing

Tests have been added, the simple ``kuard.yaml`` as well as the
included ``sonobuoy`` tool that allows for a full CNCF conformance
test. The sonobuoy tests can be invoked from the Makefile with the
``check-*`` targets. The tooling has seen a significant amount of
real-world testing during the Gaia-X Hackathon #1.

## Helm charts for cluster management

As a technical preview, we now include the Helm charts developed by our
partner StackHPC here -- they provide a more automated and more
convenient way to manage more complex cluster scenarios. We intend
to develop them further to make them become the standard in the SCS
world.
