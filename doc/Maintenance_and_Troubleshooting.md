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
