---
title: Maintenance and Troubleshooting Guide for SCS k8s-cluster-api-provider
version: 2022-09-20
authors: Kurt Garloff, Mathias Fechner, Andrej Friesen
state: Draft (v0.2)
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

Ask kubernetes what went wrong, e.g. `kubectl describe cluster <CLUSTER_NAME>`.
The status and the events may give you a clue what happened. You can also look
at the `openstackcluster` object.

You can check at the openstack layer. A cluster deployment should result in a router,
a network, a subnet, a loadbalancer (in front of kubeapi) and a number of servers (VMs)
for the control-plane and worker nodes. Have you run out of quota?

The logs of the capi pod and especially the capo pod are a good source of information.
To find out in which condition the deployment status is, you can use the following way:

``kubectl logs -n capo-system capo-manager-[TAB]``

Successful cluster creation will have these important steps:

``Successfulcreateloadbalancer``

``Reconciled Cluster create successful``

## Cluster state

You can ask cluster-api for an overview of the cluster state:
``clusterctl describe cluster <CLUSTER_NAME>``.

Have a look at the pods that run:
``kubectl --context=<CLUSTER_NAME>-admin@<CLUSTER_NAME> get pods -A``

or have a look at the nodes:
``kubectl --context=<CLUSTER_NAME>-admin@<CLUSTER_NAME> get nodes -o wide``


