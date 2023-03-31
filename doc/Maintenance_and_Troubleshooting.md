---
title: Maintenance and Troubleshooting Guide for SCS k8s-cluster-api-provider
version: 2023-03-16
authors: Kurt Garloff, Mathias Fechner, Andrej Friesen, Matej Feder
state: Draft (v0.3)
---

# Maintenance and Troubleshooting Guide for SCS k8s-cluster-api-provider

## Client Certificates in Kubernetes expire after one year.

What does a provider need to do in order to **NOT** run into a certificate issue?

1. Update the cluster at least once a year to rotate certificates automatically
    -  [Automatic certificate renewal for cluster upgrades](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/#automatic-certificate-renewal)
    - > kubeadm renews all the certificates during control plane 
        [upgrade](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/).
        This feature is designed for addressing the simplest use cases; if you don't have specific
        requirements on certificate renewal and perform Kubernetes version upgrades regularly
        (less than 1 year in between each upgrade), kubeadm will take care of keeping your
        cluster up to date and reasonably secure.

2. Renew all certificates with `kubeadm certs renew all`
    - You only need to do this when you don't upgrade your cluster
    - [kubeadm certs renew](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-certs/#cmd-certs-renew)

## Certificate Authority expires

Another problem is that the CA might expire as well (normally after 10 years)
- `kubeadm` does not have any tooling for this at the time of writing
- There is documentation for 
  [Manual Rotation of CA Certifcates](https://kubernetes.io/docs/tasks/tls/manual-rotation-of-ca-certificates/)
- On the management node, there is a `signer.sh` that can be used to sign server certificates
  after checking that they belong to the server.

## Failed cluster deployment debugging

NOTE: The following `kubectl` and `clusterctl` commands should be executed against 
the management Kubernetes cluster API. Keep in mind that these tools and the 
`kubeconfig` to access the management Kubernetes cluster are available in the management
host, hence it is convenient to execute the following commands from the management host.

Ask Kubernetes what went wrong:
```bash
kubectl describe cluster <CLUSTER_NAME>
```

The status and the events may give you a clue what happened. The healthy cluster should
be in the phase: `Provisioned`
```bash
$ kubectl describe cluster <CLUSTER_NAME> | yq .Status.Phase
Provisioned
```

You can also have a look at the `openstackcluster` object and see OpenStack related
statuses and events. The healthy cluster should be ready:
```bash
$ kubectl describe openstackcluster <CLUSTER_NAME> | yq .Status.Ready
true
```

Note that you can instead execute `kubectl get cluster <CLUSTER_NAME> -ojsonpath='{ .status.phase }'`
and `kubectl get openstackcluster <CLUSTER_NAME> -ojsonpath='{ .status.ready }'` 
if you don't have `yq` at hand.

A handy command for cluster health investigation is `clusterctl describe cluster <CLUSTER_NAME>`.
This prints infrastructure/control plane/workers readiness status and other relevant 
information like a failure reason. The healthy cluster output is similar to this:
```bash
$ clusterctl describe cluster <CLUSTER_NAME>
NAME                                                            READY  SEVERITY  REASON  SINCE  MESSAGE
Cluster/testcluster                                             True                     21m
├─ClusterInfrastructure - OpenStackCluster/testcluster
├─ControlPlane - KubeadmControlPlane/testcluster-control-plane  True                     23m
│ └─3 Machines...                                               True                     21m    See testcluster-control-plane-5ftjs, testcluster-control-plane-62cdj, ...

└─Workers
  └─MachineDeployment/capi-testcluster-md-0-no1                 True                     22m
    └─3 Machines...                                             True                     21m    See capi-testcluster-md-0-no1-84dd86f598-bhxfd, capi-testcluster-md-0-no1-84dd86f598-f6pnl, ...
```

The logs of the capi pod and especially the capo pod are a good source of information.
To find out in which condition the deployment status is, you can use the following way:

```bash
kubectl logs -n capo-system -l control-plane=capo-controller-manager -c manager
```
Successful cluster creation will log `Reconciled Machine create successfully` for 
successfully created nodes.

```bash
kubectl logs -n capi-system -l control-plane=controller-manager -c manager
```

In some cases could be a good idea to go through the official [capi]
(https://cluster-api.sigs.k8s.io/user/troubleshooting.html) and [capo](https://cluster-api-openstack.sigs.k8s.io/topics/troubleshooting.html)
troubleshooting guides or check whether you hit some known bug already reported in
[capi](https://github.com/kubernetes-sigs/cluster-api/issues?q=is%3Aissue+is%3Aopen+label%3Akind%2Fbug)
or [capo](https://github.com/kubernetes-sigs/cluster-api-provider-openstack/issues?q=is%3Aissue+is%3Aopen+label%3Akind%2Fbug) projects.

You can also check the OpenStack layer. A cluster deployment should result in a 
router,a network, a subnet, a loadbalancer (in front of kubeapi) and a number of servers (VMs)
for the control-plane and worker nodes. Have you run out of quota?

## Cluster state

Have a look at the pods that run:
``kubectl --context=<CLUSTER_NAME>-admin@<CLUSTER_NAME> get pods -A``

or have a look at the nodes:
``kubectl --context=<CLUSTER_NAME>-admin@<CLUSTER_NAME> get nodes -o wide``

If you fall into some Kubernetes specific issues after a successful cluster
creation, go through the official [Kubernetes](https://kubernetes.io/docs/tasks/debug/debug-cluster/)
troubleshooting guide.

## Etcd maintenance

[Etcd](https://etcd.io/) is a highly-available key value store used as Kubernetes'
backing store for all cluster data. This section contains etcd related maintenance
notes from SCS k8s-cluster-api-provider project perspective.

For further information about etcd maintenance visit an official [etcd maintenance guide](https://etcd.io/docs/v3.5/op-guide/maintenance/)
and/or [Kubernetes etcd operating guide](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/).

### Defragmentation and backup

Etcd storage can become fragmented over time, for this, we have included a
maintenance script that regularly defragments and then also backups the database.
The script, called `etcd-defrag.sh` is located in each control plane node's  `/root`
directory . It is executed through the systemd service unit file `etcd-defrag.service`
and scheduled to run each day at 02:30:00 using the `etcd-defrag.timer` systemd timer.

The defragmentation strategy is inspired by the [etcd-defrag-cronjob](https://github.com/ugur99/etcd-defrag-cronjob/) and
[practices recommended](https://docs.openshift.com/container-platform/4.9/scalability_and_performance/recommended-host-practices.html#automatic-defrag-etcd-data_recommended-host-practices) by the OpenShift project.
Note that the proposed strategy could be changed in a future version based on results from
related [upstream issue #15477](https://github.com/etcd-io/etcd/issues/15477) which wants to define
an official solution on how to defragment etcd cluster.

The `etcd-defrag.sh` script checks multiple conditions before the actual defragmentation as
follows:
- The script should not be executed on non leader etcd member
- The script should not be executed on etcd cluster with some unhealthy member
- The script should not be executed on single member etcd cluster

These pre-flight checks should ensure, that the defragmentation does not cause temporary
etcd cluster failures and/or unwanted etcd leader changes. They also prevent executing
the script on a single control-plane node cluster. Single-node etcd clusters are not
made for long-term operation. As a workaround, however, you can scale up to three
control-plane nodes overnight from time to time.

After all pre-flight checks passed the etcd cluster defragmentation is performed as follows:
- Defragment the non leader etcd members first
- Change the leadership to the randomly selected and defragmentation completed etcd member
- Defragment the local (ex-leader) etcd member

At the end of the defragmentation script, the local (ex-leader) etcd member is backed up
and trimmed. Backup is saved and then compressed in the control plane `/root` directory.
You can find it here: `/root/etcd-backup.xz`. File system trim is performed by the `fstrim`
command that discards unused blocks on a filesystem which could increase write performance
on the long run and also release unused storage. Cluster admins are not supposed to log
in to the cluster nodes (neither control plane nor workers) and thus won't access or use
these backup files. The local backups on these nodes however can prove useful however
in a disaster recovery scenario.

All mentioned pre-flight checks could be skipped by the optional arguments that force
defragmentation despite potential failures. Optional arguments are:
- `--force-single` (allows to execute defragmentation on single member etcd cluster)
- `--force-unhealthy` (allows to execute defragmentation on unhealthy etcd member)
- `--force-nonleader` (allows to execute defragmentation on non leader etcd member)

**We do not recommend to log in to the cluster nodes let alone executing manual
defragmentation** using the optional arguments above. If you are aware of potential
issues, you can access the control plane node and execute the defragmentation script
manually as follows:

```bash
/root/etcd-defrag.sh [--force-single] [--force-unhealthy] [--force-nonleader]
```
