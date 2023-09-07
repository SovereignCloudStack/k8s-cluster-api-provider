---
title: SCS k8s-cluster-api-provider upgrade guide
version: 2023-09-07
authors: Kurt Garloff, Roman Hros, Matej Feder
state: Draft (v0.7)
---

## SCS k8s-cluster-api-provider upgrade guide

This document explains the steps to upgrade the SCS Kubernetes cluster-API
based cluster management solution as follows:
- from the R2 (2022-03) to the R3 (2022-09) state
- from the R3 (2022-09) to the R4 state
- from the R4 (2023-09) to the R5 state
The document explains how the management cluster and the workload clusters can be
upgraded without disruption. It is highly recommended to do a step-by-step upgrade
across major releases i.e. upgrade from R2 to R3 and then to R4 in the case of
upgrade from the R2 to the R4. Upgrades across major releases without step-by-step
process is not recommended and could lead to undocumented issues.

The various steps are not very complicated, but there are numerous steps to
take, and it is advisable that cluster operators get some experience with
this kind of cluster management before applying this to customer clusters
that carry important workloads.

Note that while the detailed steps are tested and targeted to a R2 -> R3 move,
R3 -> R4 move or R4 -> R5 move, many of the steps are a generic approach that will apply also for other
upgrades, so expect a lot of similar steps when moving beyond R5.

Upgrades from cluster management prior to R2 is difficult; many changes before
R2 assumed that you would redeploy the management cluster. Redeploying the
management cluster can of course always be done, but it's typically disruptive
to your workload clusters, unless you move your cluster management state into
a new management cluster with `clusterctl move`.

## Management host (cluster) vs. Workload clusters

When you initially deployed the SCS k8s-cluster-api-provider, you create a
VM with a [kind](https://kind.sigs.k8s.io/) cluster inside and a number of
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
CaaS setups as well as the underlying IaaS. The kubectl configuration
is in `~/.kube/config` while you will find the OpenStack configuration
in `~/.config/openstack/clouds.yaml`. These files are automatically
managed; you can add entries to the files though, and they should
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
From R5 `sudo apt-get install -y jq` is also required as this is used by the diskless flavors feature, #424.
Default operating system image was changed from Ubuntu 20.04 to Ubuntu 22.04 in R4.

#### k8s-cluster-api-provider git

The automation is deployed on the management host by cloning [the relevant
git repository](https://github.com/SovereignCloudStack/k8s-cluster-api-provider).
into the `k8s-cluster-api-provider` directory. Note that the checked out
branch will be the one that has been used when creating the management host,
and you might want to change branches from `maintained/v3.x` to `maintained/v4.x`
in case of R2 to R3 upgrade, `maintained/v5.x` for R3 to R4 upgrade, or `maintained/v6.x`
for R4 to R5 upgrade.
Use `git branch -rl` to see available branches in the k8s-cluster-api-provider
repository.

You can update the scripts and templates by checking out the relevant branch
`main`, `maintained/v4.x`,  `maintained/v5.x`, or  `maintained/v6.x` and using a `git pull` to ensure
the latest content is retrieved. Once you do that, the cluster-management scripts
will be up-to-date. (The `~/bin` directory in your search `PATH` is symlinked to the
check-ed out scripts.)

Note however that the binaries and used templates are NOT automatically updated.
This should not normally result in problems -- when new features are introduced
in the management scripts, they ensure to continue to support older templates.

#### Updating cluster-API and openstack cluster-API provider

To get the latest version of cluster-API, you can download a new clusterctl
binary from <https://github.com/kubernetes-sigs/cluster-api/releases>,
make it executable `chmod +x clusterctl` and install it to `/usr/local/bin/`,
possibly saving the old binary by renaming it. `clusterctl version` should now
display the current version number (v1.3.5 at the time of this writing).

You can now issue the command `clusterctl upgrade plan` and clusterctl will
list the components in your (kind) management cluster that can be upgraded.
Here's an example output:
```bash
ubuntu@capi-old-mgmtcluster:~ [0]$ clusterctl upgrade plan
Checking cert-manager version...
Cert-Manager is already up to date

Checking new release availability...

Latest release available for the v1beta1 API Version of Cluster API (contract):

NAME                       NAMESPACE                           TYPE                     CURRENT VERSION   NEXT VERSION
bootstrap-kubeadm          capi-kubeadm-bootstrap-system       BootstrapProvider        v1.3.5            v1.5.1
control-plane-kubeadm      capi-kubeadm-control-plane-system   ControlPlaneProvider     v1.3.5            v1.5.1
cluster-api                capi-system                         CoreProvider             v1.3.5            v1.5.1
infrastructure-openstack   capo-system                         InfrastructureProvider   v0.7.1            v0.7.3

You can now apply the upgrade by executing the following command:

clusterctl upgrade apply --contract v1beta1
```

You can then upgrade the components. You can do them one-by-one or simply do
`clusterctl upgrade apply --contract v1beta1`

#### New templates

The `cluster-template.yaml` template used for the workload clusters is located in
`~/k8s-cluster-api-provider/terraform/files/template/` and copied from there into
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

#####  R2 to R3

For going from R2 to R3, there is just one real change that you want
to apply: Add the variables `CONTROL_PLANE_MACHINE_GEN: genc01` and
`WORKER_MACHINE_GEN: genw01` to it. If you have copied over the new
`cluster-template.yaml` as described above, then you're done. Otherwise
you can use the script `update-R2-R3.sh <CLUSTER_NAME>`
to tweak both `clusterctl.yaml` and `cluster-template.yaml` for the
relevant cluster. (You can use `cluster-defaults` to change the templates
in `~/cluster-defaults/` which get used when creating new clusters.)

##### R3 to R4

In the R3 to R4, CALICO_VERSION was moved from `.capi-settings` to `clusterctl.yaml`. So
before upgrading workload clusters, you must add it also to the `~/${CLUSTER_NAME}/clusterctl.yaml`.
```bash
echo "CALICO_VERSION: v3.25.0" >> ~/cluster-defaults/clusterctl.yaml
echo "CALICO_VERSION: v3.25.0" >> ~/testcluster/clusterctl.yaml
```

In the R3 to R4 upgrade process, `cluster-template.yaml` changed etcd defrag process in the
kubeadm control-planes and also security group names by adding `${PREFIX}-` to them, so it
has to be changed also in openstack project e.g. (*PREFIX=capi*):
```bash
openstack security group set --name capi-allow-ssh allow-ssh
openstack security group set --name capi-allow-icmp allow-icmp
```
We changed immutable fields in the Cluster API templates, so before running
`create_cluster.sh` to upgrade existing workload cluster the `CONTROL_PLANE_MACHINE_GEN`
and `WORKER_MACHINE_GEN` needs to be incremented in cluster specific `clusterctl.yaml`.

In the R3 to R4 process, also `cloud.conf` added `enable-ingress-hostname=true` to the
LoadBalancer section. It is due to `NGINX_INGRESS_PROXY` defaulting to true now. So if
you want to use, or you are already using this proxy functionality we recommend you to
add this line to your `cloud.conf`, e.g.:
```bash
echo "enable-ingress-hostname=true" >> ~/cluster-defaults/cloud.conf
echo "enable-ingress-hostname=true" >> ~/testcluster/cloud.conf
```
Then, before upgrading workload cluster by `create_cluster.sh`,
you should delete cloud-config secret in the kube-system namespace, so it can be recreated. E.g.:
`kubectl delete secret cloud-config -n kube-system --kubeconfig=testcluster/testcluster.yaml`

Also, the default nginx-ingress version has changed, so we recommend before upgrading cluster
to delete ingress-nginx jobs, so new job with new image can be created in the update process.
```bash
kubectl delete job ingress-nginx-admission-create -n ingress-nginx --kubeconfig=testcluster/testcluster.yaml
kubectl delete job ingress-nginx-admission-patch -n ingress-nginx --kubeconfig=testcluster/testcluster.yaml
```

##### R4 to R5

In R4 to R5, the `cluster-template.yaml` and `clusterctl.yaml` changed (see release notes).
You can use script `update-R4-to-R5.sh` to update the cluster's `cluster-template.yaml` and `clusterctl.yaml` from
R4 to R5. This script could update an existing Kubernetes cluster configuration files
as well as `cluster-defaults` files that could be used for spawning new R5 clusters.

If you want to update an existing cluster configuration files from R4 to R5, just use script as follows:
```bash
update-R4-to-R5.sh <CLUSTER_NAME>
```

After you executed the above you will find that e.g. Calico version has been bumped from
v3.25.0 to v3.26.1. Note that some software versions are not configurable and are not
directly mentioned in the cluster configuration files, but they are hardcoded
in R5 scripts (e.g. ingress nginx controller, metrics server), see [new-defaults](#new-defaults) section.
Note that the Kubernetes version was not updated as well the default CNI is not the Cilium yet.
This two R5 features are out of scope this script when it is applied on the existing cluster
configuration files as this features require advanced action such as CNI migration
and step-by-step Kubernetes upgrade of +2 minor releases.


If you want to update `cluster-defaults` configuration files from R4 to R5, just use script as follows:
```bash
update-R4-to-R5.sh cluster-defaults
```

The above action updates a cluster-defaults configuration file, which is almost similar
to updating an existing cluster configuration file described above. The distinction lies
in the fact that both the Kubernetes version and the default CNI are also updated, specifically
to Kubernetes version v1.27.5 and Cilium as a default CNI.


If you are curious: In R2, doing rolling upgrades of k8s versions required
edits in `cluster-template.yaml` -- this is no longer the case in R3, R4 and R5.
Just increase the generation counter for node and control plane nodes if you
upgrade k8s versions -- or otherwise change the worker or control plane
node specs, such as e.g. using a different flavor.

#### New defaults

You deploy a CNI (calico or cilium), the OpenStack Cloud Controller
Manager (OCCM), the cinder CSI driver to clusters; optionally also a
metrics server (default is true), a nginx ingress controller (also
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

The defaults have changed as follows:

|                | R2          | R3          | R4          | R5       |
|----------------|-------------|-------------|-------------|----------|
| kind           | v0.14.0     | v0.14.0     | v0.17.0     | v0.20.0  |
| capi           | v1.0.5      | v1.2.2      | v1.3.5      | v1.5.1   |
| capo           | v0.5.3      | v0.6.3      | v0.7.1      | v0.7.3   |
| helm           | v3.8.1      | v3.9.4      | v3.11.1     | v3.12.3  |
| sonobuoy       | v0.56.2     | v0.56.10    | v0.56.16    | v0.56.17 |
| k9s            | unversioned | unversioned | unversioned | v0.27.4  |
| calico         | v3.22.1     | v3.24.1     | v3.25.0     | v3.26.1  |
| calico CLI     | v3.22.1     | v3.24.1     | v3.25.0     | v3.26.1  |
| cilium         | unversioned | unversioned | v1.13.0     | v1.14.1  |
| cilium CLI     | unversioned | unversioned | v0.13.1     | v0.15.7  |
| hubble CLI     | unversioned | unversioned | v0.11.2     | v0.12.0  |
| nginx-ingress  | v1.1.2      | v1.3.0      | v1.6.4      | v1.8.1   |
| flux2          | unversioned | unversioned | v0.40.2     | v0.41.2  |
| cert-manager   | v1.7.1      | v1.9.1      | v1.11.0     | v1.12.4  |
| metrics-server | v0.6.1      | v0.6.1      | v0.6.1      | v0.6.4   |

### The clusterctl move approach

To be written

1. Create new management host in same project -- avoid name conflicts
   with different prefix, to be tweaked later. Avoid testcluster creation
2. Ensure it's up and running ...
3. Tweak prefix
4. Copy over configs (and a bit of state though that's uncritical) by using
   the directories
5. Copy over the openstack credentials clouds.yaml and the kubectl config
6. clusterctl move

## Updating workload clusters

### k8s version upgrade

#### On R2 clusters

The old way: Editing cluster-template.yaml. Or better use the
`update-R2-to-R3.sh` script to convert first.

#### On R3 and R4 clusters

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

#### On R5 clusters

If you decide to migrate your existing Kubernetes cluster from R4 to R5 be aware of the following: 
- R5 features such as per cluster namespaces and Calico as a default CNI are supported
  only on new clusters and will not be migrated on the existing clusters
- R4 default Kubernetes version v1.25.6 can not be directly migrated to the R5 default
  Kubernetes version v1.27.5, because +2 minor Kubernetes version upgrade is [not allowed](https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-class/operate-cluster.html?highlight=upgrade%20cluster#upgrade-a-cluster).
  See further migration steps below if you want to upgrade also Kubernetes version to R5

Follow the below steps if you want to migrate an existing cluster from R4 to R5:
1. Access your management node
2. Checkout R5 tag
   ```bash
   cd k8s-cluster-api-provider
   git pull
   git checkout tags/v6.0.0
   ```
3. Backup an existing cluster configuration files (recommended)
   ```bash
   cd ..
   cp -R <CLUSTER_NAME> <CLUSTER_NAME>-backup
   ```
4. Update an existing cluster configuration files from R4 to R5:
   ```bash
   update-R4-to-R5.sh <CLUSTER_NAME>
   ```
5. Validate updated cluster configuration files. You will find that e.g. Calico version
   has been bumped from v3.25.0 to v3.26.1. Note that some software versions are not configurable
   and are not directly mentioned in the cluster configuration files, but they are hardcoded
   in R5 scripts (e.g. ingress nginx controller, metrics server). Hence, read carefully the
   R5 release notes too. Also see that Kubernetes version was not updated, and it is still v1.25.6.
6. Update an existing cluster (expect Kubernetes version)
   ```bash
   create_cluster.sh <CLUSTER_NAME>
   ```
7. Update cluster-API and openstack cluster-API provider, see [related](#updating-cluster-api-and-openstack-cluster-api-provider) section for details
   ```bash
    clusterctl upgrade plan
    clusterctl upgrade apply --contract v1beta1
   ```
8. Bump Kubernetes version +1 minor release (to v1.26.8) and increase the generation counter for node and control plane nodes
   ```bash
   sed -i 's/^KUBERNETES_VERSION: v1.25.6/KUBERNETES_VERSION: v1.26.8/' <CLUSTER_NAME>/clusterctl.yaml
   sed -i 's/^OPENSTACK_IMAGE_NAME: ubuntu-capi-image-v1.25.6/OPENSTACK_IMAGE_NAME: ubuntu-capi-image-v1.26.8/' <CLUSTER_NAME>/clusterctl.yaml
   sed -r 's/(^CONTROL_PLANE_MACHINE_GEN: genc)([0-9][0-9])/printf "\1%02d" $((\2+1))/ge' -i <CLUSTER_NAME>/clusterctl.yaml
   sed -r 's/(^WORKER_MACHINE_GEN: genw)([0-9][0-9])/printf "\1%02d" $((\2+1))/ge' -i <CLUSTER_NAME>/clusterctl.yaml
   ```
9. Update an existing cluster Kubernetes version to v1.26.8
    ```bash
    create_cluster.sh <CLUSTER_NAME>
    ```
10. Bump Kubernetes version to R5 v1.27.5 and increase the generation counter for node and control plane nodes
   ```bash
   sed -i 's/^KUBERNETES_VERSION: v1.26.8/KUBERNETES_VERSION: v1.27.5/' <CLUSTER_NAME>/clusterctl.yaml
   sed -i 's/^OPENSTACK_IMAGE_NAME: ubuntu-capi-image-v1.26.8 /OPENSTACK_IMAGE_NAME: ubuntu-capi-image-v1.27.5/' <CLUSTER_NAME>/clusterctl.yaml
   sed -r 's/(^CONTROL_PLANE_MACHINE_GEN: genc)([0-9][0-9])/printf "\1%02d" $((\2+1))/ge' -i <CLUSTER_NAME>/clusterctl.yaml
   sed -r 's/(^WORKER_MACHINE_GEN: genw)([0-9][0-9])/printf "\1%02d" $((\2+1))/ge' -i <CLUSTER_NAME>/clusterctl.yaml
   ```
11. Update an existing cluster to the R5 Kubernetes version v1.27.5
    ```bash
    create_cluster.sh <CLUSTER_NAME>
    ```

### New versions for mandatory components

OCCM, CNI (calico/cilium), CSI

### New versions for optional components

nginx, metrics (nothing to do), cert-manager, flux

### etcd leader changes

While testing clusters with >= 3 control nodes, we have observed occasional transient
error messages that reported an etcd leader change preventing a command from succeeding.
This could result in a dozen of random failed tests in a sonobuoy conformance run.
(Retrying the commands would let them succeed.)

Too frequent etcd leader changes are detrimental to your control plane performance and
can lead to transient failures. They are a sign that the infrastructure supporting your
cluster is introducing too high latencies.

We recommend to deploy the control nodes (which run etcd) on instances with local SSD
storage (which we reflect in the default flavor name) and recommend using flavors with
dedicated cores and that your network does not introduce latencies by significant packet drop.

We now always use slower heartbeat (250ms) and increase CPU and IO priority which used to be
controlled by `ETCD_PRIO_BOOST`. This is safe.

If you build multi-controller clusters and can not use a flavor with low latency local storage
(ideally SSD), you can also work around this with `ETCD_UNSAFE_FS`. `ETCD_UNSAFE_FS` is using
`barrier=0` mount option, which violates filesystem ordering guarantees.
This works around storage latencies, but introduces the risk of inconsistent
filesystem state and inconsistent etcd data in case of an unclean shutdown.
You may be able to live with this risk in a multi-controller etcd setup.
If you don't have flavors that fulfill the requirements (low-latency
storage attached), your choice is between a single-controller cluster
(without `ETCD_UNSAFE_FS`) and a multi-controller cluster with
`ETCD_UNSAFE_FS`. Neither option is perfect, but we deem the
multi-controller cluster preferable in such a scenario.
