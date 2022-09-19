---
title: SCS k8s-cluster-api-provider update guide
version: 2022-09-19
authors: Kurt Garloff
state: Draft (v0.5)
---

# SCS k8s-cluster-api-provider upgrade guide

This document explains the steps to upgrade the SCS Kubernetes cluster-API
based cluster management solution from the R2 (2022-03) to the R3 state,
explaining how the management cluster and the workload clusters can be
upgraded without disruption.

The various steps are not very complicated, but there are numerous steps to
take and it is advisable that cluster operators get some experience with
this kind of cluster management before applying this to customer clusters
that carry important workloads.

Note that while the detailed steps are tested and targeted to a R2 -> R3 move,
many of the steps are a generic approach that will apply also for other
upgrades, so expect a lot of similar steps when moving beyond R3.
Upgrades from cluster management prior to R2 is difficult; many changes before
R2 assumed that you would redeploy the management cluster. Redploying the
management cluster can of course always be done, but it's typically disruptive
to your workload clusters, unless you move your cluster management state into
a new management cluster with `clusterctl move`.

## Management host (cluster) vs. Workload clusters

When you initially deployed the SCS k8s-cluster-api-provider, you create a
VM with a kind(https://kind.sigs.k8s.io/) cluster inside and a number of
templates, scripts and binaries that are then used to do the cluster management.
This is your management host (or more precisely you single-host management
cluster). Currently, all cluster management including upgrading etc. is done
by connecting to this host via ssh and performing commands there. (You don't
need root privileges to do cluster management there, the normal ubuntu user
rights are sufficient; there are obviously host management tasks such as
installing package updates that do require root power and the user has the
sudo rights to do so.)

When you create the management host, you have the option to create your
first workload cluster. This cluster is no different from other workload
clusters that you create by calling commands on the management host, so you
can manage it there. (The default name of this cluster is typically
`testcluster`, though that can be changed since a while, #264).

On the management host, you have the openstack and kubernetes tools
installed and configured, so you can nicely manage all aspects of your
CaaS setups as well as the underlaying IaaS. The kubectl configuration
is in `~/.kube/config` while you will find the OpenStack configuration
in `~/.config/openstack/clouds.yaml`. These files are automatically
managed; you can add entries to the files though and they should
persist.

## Updating the management host

There are two different possibilities to upgrade the management host.
1. You do a component-wise in-place upgrade of it.
2. You deploy a new management host and `clusterctl move` the resources
   over to it from the old one. (Note: Config state in `~/CLUSTER_NAME/`)

TODO: Advice when to do what, risks, limitations

### In-place upgrade

#### Operating system

You should keep the host up-to-date with respect to normal operating system
upgrades, so perform your normal `sudo apt-get update && sudo apt-get upgrade`.
`kubectl`, `kustomize`, `yq`, `lxd` and a few other tools are installed as
snaps, so you may want to upgrade these as well: `sudo snap refresh`.

#### k8s-cluster-api-provider git

The automation is deployed on the management host by cloning [the relevant
git repository](https://github.com:SovereignCloudStack/k8s-cluster-api-provider/).
into the `k8s-cluster-api-provider` directory. Note that the checked out
branch will be the one that has been used when creating the management host
and you might want to change branches from `maintained/v3.x` to `maintained/v4.x`.
Use `git branch -rl` to see available branches in the k8s-cluster-api-provider
repository.

You can update the scripts and templates by checking out the relevant branch
`main` or `maintained/v4.x` and using a `git pull` to ensure the latest content
is retrieved. Once you do that, the cluster-management scripts will be up-to-date.
(The `~/bin` directory in your search `PATH` is symlinked to the check-ed out
scripts.)

Note however that the binaries and used templates are NOT automatically updated.
This should not normally result in problems -- when new features are introduced
in the management scripts, they ensure to continue to support older templates.

#### Updating cluster-API and openstack cluster-API provider

To get the latest version of cluster-API, you can download a new clusterctl
binary from <https://github.com/kubernetes-sigs/cluster-api/releases/>,
make it executable `chmod +x clusterctl` and install it to `/usr/local/bin/`,
possibly saving the old binary by renaming it. `clusterctl version` should now
display the current version number (v1.2.2 at the time of this writing).

You can now issue the command `clusterctl upgrade plan` and clusterctl will
list the components in your (kind) management cluster that can be upgraded.
Here's an example output:
```
TBW

```

You can then upgrade the components ...

#### New templates

The `cluster-template.yaml` template used for the the workload clusters is located in
`~/k8s-cluster-api-provider/terraform/files/templates/` and copied from there into
`~/cluster-defaults/`. Then workload clusters are created, they will also have a
copy of it in `~/${CLUSTER_NAME}/`. If you have not changed it manually, you can
copy it over the old templates. (Consider backing up the old one though.)

The next `create_cluster.sh <CLUSTER_NAME>` run will then use the new template.
Note that `create_cluster.sh` is idempotent -- it will not perform any changes
on the cluster unless you have changed its configuration by tweaking
`cluster-template.yaml` (which you almost never do!) or `clusterctl.yaml`
(which you do often).

The other template file that changed -- however, some terraform logic is used to
prefill it with values. So you can't copy it from git.
Instead for going from R2 to R3, there is just one real change that you want
to apply: Add the variables `CONTROL_PLANE_MACHINE_GEN: genc01` and
`WORKER_MACHINE_GEN: genw01` to it. If you have copied over the new
`cluster-template.yaml` as described above, then you're done. Otherwise
you can use the script `update-cluster-template-to-generation-counted.sh <CLUSTER_NAME>`
to tweak both `clusterctl.yaml` and `cluster-template.yaml` for the
relevant cluster. (You can use `cluster-defaults` to change the templates
in `~/cluster-defaults/` which get used when creating new clusters.)

If you are curious: In R2, doing rolling upgrades of k8s versions reqiured
edits in `cluster-template.yaml` -- this is no longer the case in R3. Just
increase the generation counter for node and control plane nodes if you
upgrade k8s versions -- or otherwise change the worker or control plane
node specs, such as e.g. using a different flavor.

#### New defaults

You deploy a CNI (calico or cilium), the OpenStack Cloud Controller
Manager (OCCM), the cinder CSI driver to clusters; optionally also a
metrics server (default is true), an nginx ingress controller (also
defaulting to true), the flux2 controller, the cert-manager.
Some of these tools come with binaries that you can use for management
purposes and which get installed on the management host in `/usr/local/bin/`.

The scripts that deploy these components into your workload clusters
download the manifests into `~/kubernetes-manifests.d/` with a version
specific name. If you request a new version, a new download will happen;
already existing versions will not be re-downloaded.

Most binaries in `/usr/local/bin/` are not stored under a version-specific
name. You need to rename them to case a re-download of a newer version.
(The reason for not having version specific names is that this would
 break scripts from users that assume the unversioned names; the good
 news is that most of these binaries have no trouble managing somewhat
 older deployments, so you can typically work with the latest binary
 tool even if you have a variety of versions deployed into various
 clusters.)

The defaults have changed as follows

TODO: TABLE

TODO: calico und cilium tooling note

### The clusterctl move approach

To be written
1. Create new management host in same project -- avoid name conflicts
   with different prefix, to be tweaked later. Avoid testcluster creation.
2. Ensure it's up an running ...
3. Tweak prefix
4. Copy over configs (and a bit of state though that's uncritical) by using
   the directories
5. Copy over the openstack credentials clouds.yaml and the kubectl config.
6. clusterctl move 

## Updating workload clusters

### k8s version upgrade

#### On R3 clusters

Edit `~/<CLUSTER_NAME>/clusterctl.yaml` and put the wanted version into the
fields `KUBERNETES_VERSION` and `OPENSTACK_IMAGE_NAME`. The node image will
be downloaded from <https://minio.services.osism.tech/openstack-k8s-capi-images>
and registered if needed. (If you have updated the k8s-cluster-api-provider repo,
you can use a version v1.NN.x, where you fill in NN with the wanted k8s version,
but leave a literal `.x` which will get translated to the newest tested version.)

In the same file, increase the generation counters for `CONTROL_PLANE_MACHINE_GEN`
and `WORKER_MACHINE_GEN`.

Now do the normal `create_cluster.sh <CLUSTER_NAME>` and watch cluster-api
replace your worker nodes and doing a rolling upgrade of your control plane.
If you used a 3-node (or 5 or higher) control plane node setup, you will have
uninterrupted access not just to your workloads but also the workload's cluster
control plane. Use `clusterctl describe cluster <CLUSTER_NAME>` or simply
`kubectl --context <CLUSTER_NAME>-admin@<CLUSTER_NAME> get nodes -o wide`
to watch the progress of this.

#### On R2 clusters

The old way: Editing cluster-template.yaml. Or better use the 
`update-cluster-template-to-generation-counted.sh` script to convert first.

### New versions for mandatory components

OCCM, CNI (calico/cilium), CSI

### New versions for optional components

nginx, metrics (nothing to do), cert-manager, flux

