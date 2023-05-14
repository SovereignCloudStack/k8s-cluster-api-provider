# Overview

Creating and scaling k8s clusters on demand is providing a lot of flexibility to DevOps teams that develop, test, deploy and operate services and applications.

We expect the functionality to be mainly consumed in two scenarios:

- Self-service: The DevOps team leverages the code provided from this repository to create their own capi management server and use it then to manage a number of k8s clusters for their own needs.
- Managed k8s: The Operator's service team creates the capi management server and uses it to provide managed k8s clusters for their clients.

Note that we have an intermediate model in mind -- a model where a one-click / one-API call interface would allow the management server to be created on behalf of a user and then serve as an API endpoint to that user's k8s CAPI needs. Ideally with some dashboard or GUI that would shield less experienced users from all the YAML.

Once we as the SCS Communtiy have the gitops style cluster control working, the self-service model will become more convenient to use.

Basically, this repository covers two topics:

1. Automation (terraform, Makefile) to bootstrap a cluster-API management server by installing kind on a vanilla Ubuntu image and deploying some tools on this node ([kubectl](https://kubernetes.io/docs/reference/kubectl/overview/), [openstack CLI tools](https://docs.openstack.org/newton/user-guide/common/cli-install-openstack-command-line-clients.html), [k9s](https://github.com/derailed/k9s), [cilium](https://cilium.io/), [calico](https://www.tigera.io/tigera-products/calico/), [helm](https://helm.sh/), [flux](https://fluxcd.io/) ...) and deploying [cluster-API](https://cluster-api.sigs.k8s.io/) (clusterctl) and the [OpenStack cluster-api provider](https://github.com/kubernetes-sigs/cluster-api-provider-openstack) along with suitable credentials. The terraform automation is driven by a Makefile for convenience. The tooling also contains all the logic to clean up again. The newly deployed node clones this git repository early in the bootstrap process and uses the thus received files to set up the management cluster and scripts.

2. This node can be connected to via ssh and the deployed scripts there can be used to manage workload clusters and then deploy various standardized tools (such as e.g. [OpenStack Cloud Controller Manager](https://github.com/kubernetes/cloud-provider-openstack)(OCCM), [cinder CSI](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/cinder-csi-plugin/using-cinder-csi-plugin.md), calico or cilium CNI, [nginx ingress controller](https://kubernetes.github.io/ingress-nginx/), [cert-manager](https://cert-manager.io/), ...) and run tests (e.g. CNCF conformance with [sonobuoy](https://sonobuoy.io/)). The tools and artifacts can be updated via `git pull` at any time and the updated settings rolled out to the workload clusters. Note that the script collection will eventually be superseded by the [capi-helm-charts](https://github.com/stackhpc/capi-helm-charts). The medium-term goal is to actually create a reconciliation loop here that would perform life-cycle-management for clusters according to the cluster configuration stored in an enhanced [cluster-api style](https://cluster-api.sigs.k8s.io/clusterctl/configuration.html) clusterctl.yaml from git repositories and thus allow a pure [gitops](https://www.weave.works/technologies/gitops/) style cluster management without ever ssh'ing to the management server.
