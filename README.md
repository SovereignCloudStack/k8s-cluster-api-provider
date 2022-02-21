# k8s-cluster-api-provider

This guide shows you how to get working Kubernetes clusters on a SCS cloud
via [cluster-api](https://cluster-api.sigs.k8s.io/).

Cluster API requires an existing Kubernetes cluster. It is built with [kind](https://kind.sigs.k8s.io/)
on an OpenStack instance created via Terraform. This instance can be used later on for the management
of the newly created cluster, or for creating additional clusters.

Basically, this repository covers two topics:
1. Automation (terraform) to bootstrap a cluster-API management node by installing
   kind on a vanilla Ubuntu image and deploying some tools on this node (
   [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/),
   [openstack CLI tools](https://docs.openstack.org/newton/user-guide/common/cli-install-openstack-command-line-clients.html),
   [k9s](https://github.com/derailed/k9s),
   [cilium](https://cilium.io/),
   [calico](https://www.tigera.io/tigera-products/calico/),
   [helm](https://helm.sh/),
   [flux](https://fluxcd.io/) ...) and deploying
   [cluster-API]((https://cluster-api.sigs.k8s.io/) (clusterctl) and the
   [OpenStack cluster-api provider](https://github.com/kubernetes-sigs/cluster-api-provider-openstack)
   along with suitable credentials. The terraform automation is driven by a Makefile for
   convenience. The tooling also contains all the logic to clean up again.
1. This node can be connected to via ssh and the deployed scripts there can be
   used to manage clusters and then deploy various standardized tools (such
   as e.g. [OpenStack Cloud Controller Manager](https://github.com/kubernetes/cloud-provider-openstack)(OCCM),
   [cinder CSI](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/cinder-csi-plugin/using-cinder-csi-plugin.md),
   calico or cilium,
   [nginx ingress controller](https://kubernetes.github.io/ingress-nginx/),
   [cert-manager](https://cert-manager.io/), ...) and run tests (e.g. CNCF conformance
   with [sonobuoy](https://sonobuoy.io/)). Note that the script collection will
   eventually be superceded by the
   [capi-helm-charts](https://github.com/stackhpc/capi-helm-charts). The
   medium-term goal is to actually create a reconciliation loop here that would
   perform life-cycle-management for clusters according to the cluster configuration
   stored in an enhanced [cluster-api style](https://cluster-api.sigs.k8s.io/clusterctl/configuration.html)
   clusterctl.yaml from git repositories
   and thus allow a pure [gitops](https://www.weave.works/technologies/gitops/) style
   cluster management without ever ssh'ing to the management node.

## Intended audience

Creating and scaling k8s clusters on demand is providing a lot of flexibility to
DevOps teams that develop, test, deploy and operate services and applications.

We expect the functionality to be mainly consumed in two scenarios:

* Self-service: The DevOps team leverages the code provided from this repository
  to create their own CAPI management server and use it then to manage a number
  of k8s clusters for their own needs.

* Managed k8s: The Operator's service team creates the CAPI management server and
  uses it to provide managed k8s clusters for their clients.

Note that we have an intermediate model in mind -- a model where a one-click / one-API
call interface would allow the management server to be created on behalf of a user
and then serve as an API endpoint to that user's k8s capi needs. Ideally with some
dashboard or GUI that would shield less experienced users from all the YAML.

Once we have the gitops style cluster control working, the self-service model
will become more convenient to use.

## Preparations

* Terraform must be installed (<https://learn.hashicorp.com/tutorials/terraform/install-cli>).
* You must have credentials to access the cloud. terraform will look for ``clouds.yaml``
  and ``secure.yaml`` in the current working directory, in ``~/.config/openstack/``
  and ``/etc/openstack`` (in this order), just like the openstack client.
  (<https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml>)
* You need to have ``yq`` (python3-yq or yq snap) installed.
* As the ``v3applicationcredential`` ``auth_type`` plugin is being used, we hit a bug
  in Ubuntu 20.04 which ships python3-keystoneauth < 4.2.0, which does fail with
  unversioned ``auth_url`` endpoints.
  (See OpenStack [bug 1876317](https://bugs.launchpad.net/keystoneauth/+bug/1876317).)
  While we try to patch the bug away in the deployed instance, the patching mechanism
  is not very robust, so we still recommend you have a versioned ``auth_url``
  endpoint (with a trailing ``/v3``).
* Copy the environments sample file from environments/environment-default.tfvars to
  ``environments/environment-<yourcloud>.tfvars`` and provide the necessary information like
  machine flavor or machine image. (See below for more details on this.)
* Pass ``ENVIRONMENT=<yourcloud>`` to the ``make`` command or export ``ENVIRONMENT`` from
  your shell's environment. If the name of the environment equals the name of the cloud
  as specified in your ``clouds.yaml``, you can also just set ``OS_CLOUD`` in your shell's
  environment. (You can also edit the default in the Makefile, though we don't recommend
  this.)

## Usage

* ``make create``

This will create an application credential, networks, security groups and a virtual machine
which gets bootstrapped with an installation of some tools and a local kubernetes cluster
(with kind), where the cluster API provider will be installed and which will provide the
API server for the k8s CAPI. If the number of control nodes ``controller_count`` in
your config (``environment-<yourcloud>.tfvars``) is zero, then that's all that is done.
Otherwise, a testcluster will be created using k8s CAPI.

The subsequent management of the cluster can best be done from the VM, as it has all
the tools deployed there and config files can be edited and resubmitted to the kubernetes
kind cluster for reconciliation. To log in to this management machine via ssh, you can
issue ``make ssh``.  The kubeconfig with admin
power for the created testcluster is named ``testcluster.yaml`` and can be handed out to
users that should get full administrative control over the cluster.

## Teardown

``make clean`` does ssh to the C-API management server to clean up the created clusters prior
to terraform cleaning up the resources it has created. This is sometimes insufficient to clean up
unfortunately, some error in the deployment may result in resources left around.
``make fullclean`` uses a custom script (using the
openstack CLI) to clean up trying to not hit any resources not created by the capi or terraform.
It is the recommended way for doing cleanups if ``make clean`` fails.

You can purge the whole project via ``make purge``. Be careful with that command as it will purge
*all resources in the OpenStack project* even those that have not been created through this Terraform script.
It requires the [``ospurge``](https://opendev.org/x/ospurge) script.
Install it with ``python3 -m pip install git+https://git.openstack.org/openstack/ospurge``.

Note that ``clean`` and ``fullclean`` leave the ``ubuntu-capi-image-$KUBERNETES_VERSION`` image registered,
so it can be reused.
You need to manually unregister it, if you want your next deployment to register a new image with
the same kubernetes version number.

## Extensions

You can use this repository as a starting point for some automation e.g. adding
kubernetes manifests to the cluster or to run custom shell scripts in the end.
To do so place your files in the `terraform/extension` folder.  They will be
uploaded to the management cluster. Files ending in ```*.sh``` will be executed
in alphabetical order. All other files will just be uploaded. If you want to
deploy resources in the new cluster-api-maintained cluster you can use `kubectl
apply -f <your-manifest.yaml> --kubeconfig ~/testcluster.yaml` to do so.

## Application Credentials

The terraform creates an [application credential](https://docs.openstack.org/keystone/wallaby/user/application_credentials.html)
that it passes into the created VM.
This one is then used to authenticate the cluster API provider against the OpenStack
API to allow it to create resources needed for the k8s cluster.

The AppCredential has a few advantages:

* We take out variance in how the authentication works -- we don't have to
  deal with a mixture of project_id, project_name, project_domain_name,
  user_domain_name, only a subset of which is needed depending on the cloud.
* We do not leak the user credentials into the cluster, making any security
  breach more easy to contain.
* AppCreds are connected to one project and can be revoked.

Currently, we are using restricted AppCreds which can not create further AppCreds.
This means that all clusters created from the management node will belong to the
same OpenStack project and use the same credentials. Obviously, nothing prevents
you from copying a secondary AppCred into the VM and creating appropriate
secrets to talk to other projects or other clouds simultaneously.

The plan for the future is to create AppCreds per cluster 
(see [#109](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/109)),
so credentials for individual clusters can be revoked.

## Cluster Management on the C-API management node

You can use ``make ssh`` to log in to the C-API management node. There you can issue
``clusterctl`` and ``kubectl`` (aliased to ``k``) commands. The context ``kind-kind``
is used for the C-API management while the context ``testcluster-admin@testcluster`` can
be used to control the workload cluster ``testcluster``. You can of course create many
of them. There are management scripts on the management node:

* ``create_cluster.sh [CLUSTERNAME]``: Use this command to use the template
  ``cluster-template.yaml`` with the variables from ``clusterctl[-$CLUSTERNAME].yaml``
  to render a config file ``$CLUSTERNAME-config.yaml`` which will then be submitted
  to the capi server (``kind-kind`` context) for creating the control plane nodes
  and worker nodes with openstack integration, cinder CSI, calico or cilium CNI,
  metrics server, and optionally nginx ingress controller, flux, cert-manager. 
  (The latter of these can be controlled by ``tfvars`` which are passed down
   into the ``clusterctl.yaml``.)
  The script makes sure that appropriate capi images are available (it grabs them
  from [OSISM](https://minio.services.osism.tech/openstack-k8s-capi-images)
  as needed and registers them with OpenStack, following the SCS image metadata
  standard.
  The script returns once the control plane is fully working (the worker
  nodes might still be under construction). The kubectl file to talk to this
  cluster (as admin) can be found in ``$CLUSTERNAME.yaml``. Expect the cluster
  creation to take ~8mins. (CLUSTERNAME defaults to testcluster.) You can pass
  ``--context=${CLUSTERNAME}-admin@$CLUSTERNAME`` to ``kubectl`` (with the
  default ``~/.kubernetes/config`` config file) or ``export KUBECONFIG=$CLUSTERNAME.yaml``\
  to talk to the workload cluster.
* The installaton of the openstack integration, cinder CSI, metrics server and
  nginx ingress controller is done via the ``bin/apply_*.sh`` scripts that are called
  from ``create_cluster.sh``. You can manually call them as well -- they take
  the cluster name as argument. The applied yaml files are left in the user's
  home directory -- you can ``kubectl delete -f`` them to remove the functionality
  again.
* The ``create_cluster.sh`` script can be called with an existing cluster to apply
  changes to it.
  Note that you can easily change the number of nodes or add k8s services to a
  cluster, while the node specifications itself (flavor, image, ...) can not
  be changed. You need to add a second machine
  description template to the ``cluster-template.yaml`` to do such changes;
  the machine description names carry a ``-genwN`` (worker) resp. ``-gencN``
  suffix that is meant to be adjusted for this purpose.
  You will also need to enhance it for multi-AZ or multi-region clusters.
  You can of course also delete the cluster and create a new one if that
  level of disruption is fine for you. (See below in Advanced cluster templating
  with helm to get an idea how we want to make this more convenient in the future.)
* Use ``kubectl get clusters`` in the ``kind-kind`` context to see what clusters
  exist. Use ``kubectl get all -A`` in the ``testcluster-admin@testcluster`` context
  to get an overview over the state of your workload cluster. You can access the logs
  from the capo controller in case you have trouble with cluster creation.
* ``delete_cluster.sh [CLUSTERNAME]``: Tell the capi mgmt server to remove
  the cluster $CLUSTERNAME. It will also remove persistent volume claims belonging
  to the cluster. The script will return once the removal is done.
* ``cleanup.sh``: Remove all running clusters.

For your convenience, ``k9s`` is installed on the management node as well
as ``calicoctl``, ``cilium``, ``hubble``, ``cmctl``, ``helm`` and ``sonobuoy``.
These binaries can all be found in ``/usr/local/bin`` while the helper scripts
have been deployed to ``~/bin/``.

## Managing many clusters

While the scripts all use a default ``testcluster``, they have
been developed and tested to manage many clusters from a single management
node. Copy the ``clusterctl.yaml`` file to ``clusterctl-MYCLUSTER.yaml``
and edit the copy to describe the properties of the cluster to be created.
Use ``./create_cluster.sh MYCLUSTER`` then to create a workload cluster
with the name ``MYCLUSTER``. You will find the kubeconfig file in
``MYCLUSTER.yaml``, granting its owner admin access to that cluster.
Likewise, ``delete_cluster.sh`` and the ``aaply_*.sh`` scripts take a
cluster name as parameter.

This way, dozens of clusters can be controlled from one management node.

## Testing

To test the created k8s cluster, there are several tools available.
Apply all commands to the testcluster context (by passing the appropriate
``--context`` setting to ``kubectl`` or by using the right ``KUBECONFIG``
file).

* Looking at all pods (``kubectl get pods -A``) to see that they all come
  up (and don't suffer excessive restarts) is a good first check.

* You can create a very simple deployment with the provided ``kuard.yaml``, which is
  an example taken from the O'Reilly book from B. Burns, J. Beda, K. Hightower:
  "Kubernetes Up & Running" enhanced to also use a persistent volume.

* You can deploy [Google's demo microservice application](https://github.com/GoogleCloudPlatform/microservices-demo).

* ``sonobuoy`` runs a subset of the k8s tests, providing a simple way to
  filter the >5000 existing test cases to only run the CNCF conformance
  tests or to restrict to non-disruptive tests. The ``sonobuoy.sh`` wrapper
  helps with calling it. There are also ``Makefile`` targets ``check-*`` that
  call various [sonobuoy](https://sonobuoy.io) test sets.
  This is how we call sonobuoy for our CI tests.

* You can use `cilium connectivity test` to check whether your cilium
  CNI is working properly. You will have to add two rules to the security
  group `k8s-cluster-testcluster-cilium` though to allow for the NodePorts
  to be accessible. As these ports are created dynamically, this is not
  preconfigured.

## etcd leader changes

While testing clusters with >= 3 control nodes, we have observed
occasional transient error messages that reported an etcd leader
change preventing a command from succeeding. This could result
in a dozen of random failed tests in a sonobuoy conformance run.
(Retrying the commands would let them succeed.)

Too frequent etcd leader changes are detrimental to your control
plane performance and can lead to transient failures. They are a sign
that the infrastructure below your cluster is introducing too high
latencies (>100ms in the default configuration which we don't change).

We recommend to deploy the control nodes (which run etcd) on instances
with SSD storage (which we reflect in the default flavor name) and
recommend ensuring that the CPU oversubscription is low and that
your network does not introduce latencies by significant packet drop.

## Multi-AZ and multi-cloud environments

The provided ``cluster-template.yaml`` assumes that all control nodes
on one hand and all worker nodes on the other are equal. They are in the
same cloud within the same availablity zone, using the same flavor.
cluster API allows k8s clusters to have varying flavors, span availability
zones and even clouds. For this, you can create an advanced
cluster-template with more different machine descriptions and potentially
several secrets. Depending on your changes, the logic in ``create_cluster.sh``
might also need enhancements to handle this. Extending this is not hard
and we're happy to hear from your use cases and take patches.

However, we are currently investigating to use helm templating for anything
beyond the simple use cases instead, see next chapter.

## Advanced cluster templating with helm (Technical Preview)

On the management node, we have not only helm installed, but also the
repository [https://github.com/stackhpc/capi-helm-charts](https://github.com/stackhpc/capi-helm-charts)
checked out. Amongst other things, it automates the creation of new machine
templates when needed and doing rolling updates on your k8s cluster
with clusterctl. This allows for an easy adaptation of your cluster to
different requirements, new k8s versions etc.

Please note that this is currently evolving quickly and we have not
completely assessed and tested the capabilities. We intend to do
this after R1 and eventually recommend this as the standard way
of managing clusters in production. At this point, it's included as a
technical preview.

## Overview over the parameters in clusterctl.yaml and environment-XXX.tfvars

Parameters controlling the Cluster-API management node (capi mgmt node) creation:

environment | clusterctl.yaml | provenance | default |  meaning
---|---|---|---|---
`prefix` | | SCS | `capi` | Prefix used for OpenStack resources for the capi mgmt node
`kind_flavor` | | SCS | `SCS-1V:4:10` | Flavor to be used for the k8s capi mgmt node
`image` | | SCS | `Ubuntu 20.04` | Image to be deployed for the capi mgmt node
`ssh_username` | | SCS | `ubuntu` | Name of the default user for the `image`
`clusterapi_version` | | SCS | `1.0.4` | Version of the cluster-API incl. `clusterctl`
`capi_openstack_version` | | SCS | `0.5.0` | Version of the cluster-api-provider-openstack (needs to fit the capi version)

Parameters controlling both management node creation and cluster creation:

environment | clusterctl.yaml | provenance | default |  meaning
---|---|---|---|---
`cloud_provider` | `OPENSTACK_CLOUD` | capo | | `OS_CLOUD` name in clouds.yaml
`external` | `OPENSTACK_EXTERNAL_NETWORK_ID` | capo | | Name/ID of the external (public) OpenStack network
`dns_nameserver` | `OPENSTACK_DNS_NAMESERVERS` | capo | `9.9.9.9` | List of nameservers for capi mgmt nodes and for cluster nodes
`availability_zone` | `OPENSTACK_FAILURE_DOMAIN` | capo | | Availability Zone(s) for the mgmt node / workload clusters
`kind_mtu` | `MTU_VALUE` | SCS | `0` | MTU for the mgmt node; Calico is set 50 bytes smaller; 0 means autodetection

Parameters controlling the cluster creation:

environment | clusterctl.yaml | provenance | default |  meaning
---|---|---|---|---
`node_cidr` | `NODE_CIDR` | SCS | `10.8.0.0/20` | IPv4 address range (CIDR notation) for workload nodes
`use_cilium` | `USE_CILIUM` | SCS | `false` | Use cilium as CNI instead of calico
`calico_version` | | SCS | `v3.22.0` | Version of the Calico CNI provider (ignored if `use_cilium` is set)
`kubernetes_version` | `KUBERNETES_VERSION` | capo | `v1.21.9` | Kubernetes version deployed into workload cluster
` ` | `OPENSTACK_IMAGE_NAME` | capo | `ubuntu-capi-image-${KUBERNETES_VERION}` | Image name for k8s controller and worker nodes
`kube_image_raw` | `OPENSTACK_IMAGE_RAW` | SCS | `false` | Register images in raw format (instead of qcow2), good for ceph COW
`image_registration_extra_flags` | `OPENSTACK_IMAGE_REGISTATION_EXTRA_FLAG` | SCS | `""` | Extra flags passed during image registration
` ` | `OPENSTACK_CONTROL_PLANE_IP` | capo | `127.0.0.1` | Use localhost to talk to capi cluster (don't change on capi mgmt node)
` ` | `OPENSTACK_SSH_KEY_NAME` | capo | `${prefix}-keypair` | SSH key name generated and used to connect to workload cluster nodes
`controller_flavor` | `OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR` | capo | `SCS-2V:4:20s` | Flavor to be used for control plane nodes
`worker_flavor` | `OPENSTACK_NODE_MACHINE_FLAVOR` | capo | `SCS-2V:4:20` | Flavor to be used for worker nodes
`controller_count` | `CONTROL_PLANE_MACHINE_COUNT` | capo | `1` | Number of control plane nodes in testcluster (0 skips testcluster creation)
`worker_count` | `WORKER_MACHINE_COUNT` | capo | `3` | Number of worker nodes in testcluster
`anti_affinity` | `OPENSTACK_ANTIAFFINITY` | SCS | `false` | Use anti-affinity server groups to prevent k8s nodes on same host (soft for workers, hard for controllers)
` ` | `OPENSTACK_SRVGRP_CONTROLLER` | SCS | `nonono` | Autogenerated if `anti_affinity` is `true`, eliminated otherwise
` ` | `OPENSTACK_SRVGRP_WORKER` | SCS | `nonono` | Autogenerated if `anti_affinity` is `true`, eliminated otherwise
`deploy_k8s_openstack_git` | `DEPLOY_K8S_OPENSTACK_GIT` | SCS | `false` | Deploy latest upstream OCCM version from git instead of v1.19.2
`deploy_k8s_cindercsi_git` | `DEPLOY_K8S_CINDERCSI_GIT` | SCS | `false` | Deploy latest upstream cinder CSI version from git instead of v2.2.0

Optional services deployed to cluster:

environment | clusterctl.yaml | provenance | default | script |  meaning
---|---|---|---|---|---
`deploy_metrics_service` | `DEPLOY_METRICS` | SCS | `true` | `apply_metrics.sh` | Deploy metrics service to nodes to make `kubectl top` work
`deploy_nginx_ingress` | `DEPLOY_NGINX_INGRESS` | SCS | `true` | `apply_nginx_ingress.sh` | Deploy NGINX ingress controller (this spawns an OpenStack Loadbalancer)
`deploy_cert_manager` | `DEPLOY_CERT_MANAGER` | SCS | `false` | `apply_cert-manager.sh` | Deploy cert-manager
`deploy_flux` | `DEPLOY_FLUX` | SCS | `false` | | Deploy flux2 into the cluster

The provenance capo means that this setting comes from the templates used by the cluster-api-provider-openstack.

## TODO

* Unify settings naming ([#136](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/136))
* Move towards per cluster app creds ([#109](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/109))
* Opt-in for per cluster project (extends [#109](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/109))
* Subdirectories per cluster on capi mgmt node ([#107](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/107), see also [#117](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/117)).
* Allow service deletion from `create_cluster.sh` ([#137](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/137), see also [#131](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/131))
* More pre-flight checks in `create_clster.sh` ([#111](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/111)).
* Allow using newer OCCM and cinder CSI providers with fixed and tested versions. ([#138](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/138))
* Implement (optional) harbor deployment using k8s-harbor. ([#139](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/139))
* Move towards gitops style cluster management. (Design Doc in [Docs repo PR #47](https://github.com/SovereignCloudStack/Docs/pull/47) - draft)


