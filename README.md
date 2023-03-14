# k8s-cluster-api-provider

This guide shows you how to get working Kubernetes clusters on a SCS cloud
via [cluster-api](https://cluster-api.sigs.k8s.io/)(CAPI).

Cluster API requires an existing Kubernetes cluster. It is built with [kind](https://kind.sigs.k8s.io/)
on an OpenStack instance created via Terraform. This instance, called capi management server or management
cluster can be used later on for the management
of the newly created cluster, and for creating and managing additional clusters.

Basically, this repository covers two topics:
1. Automation (terraform, Makefile) to bootstrap a cluster-API management server by
   installing kind on a vanilla Ubuntu image and deploying some tools on this node (
   [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/),
   [openstack CLI tools](https://docs.openstack.org/newton/user-guide/common/cli-install-openstack-command-line-clients.html),
   [k9s](https://github.com/derailed/k9s),
   [cilium](https://cilium.io/),
   [calico](https://www.tigera.io/tigera-products/calico/),
   [helm](https://helm.sh/),
   [flux](https://fluxcd.io/) ...) and deploying
   [cluster-API](https://cluster-api.sigs.k8s.io/) (clusterctl) and the
   [OpenStack cluster-api provider](https://github.com/kubernetes-sigs/cluster-api-provider-openstack)
   along with suitable credentials. The terraform automation is driven by a Makefile for
   convenience. The tooling also contains all the logic to clean up again.
   The newly deployed node clones this git repository early in the bootstrap
   process and uses the thus received files to set up the management
   cluster and scripts.
2. This node can be connected to via ssh and the deployed scripts there can be
   used to manage workload clusters and then deploy various standardized tools (such
   as e.g. [OpenStack Cloud Controller Manager](https://github.com/kubernetes/cloud-provider-openstack)(OCCM),
   [cinder CSI](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/cinder-csi-plugin/using-cinder-csi-plugin.md),
   calico or cilium CNI,
   [nginx ingress controller](https://kubernetes.github.io/ingress-nginx/),
   [cert-manager](https://cert-manager.io/), ...) and run tests (e.g. CNCF conformance
   with [sonobuoy](https://sonobuoy.io/)).
   The tools and artifacts can be updated via `git pull` at any time and
   the updated settings rolled out to the workload clusters.
   Note that the script collection will
   eventually be superseded by the
   [capi-helm-charts](https://github.com/stackhpc/capi-helm-charts). The
   medium-term goal is to actually create a reconciliation loop here that would
   perform life-cycle-management for clusters according to the cluster configuration
   stored in an enhanced [cluster-api style](https://cluster-api.sigs.k8s.io/clusterctl/configuration.html)
   clusterctl.yaml from git repositories
   and thus allow a pure [gitops](https://www.weave.works/technologies/gitops/) style
   cluster management without ever ssh'ing to the management server.

## Intended audience

Creating and scaling k8s clusters on demand is providing a lot of flexibility to
DevOps teams that develop, test, deploy and operate services and applications.

We expect the functionality to be mainly consumed in two scenarios:

* Self-service: The DevOps team leverages the code provided from this repository
  to create their own capi management server and use it then to manage a number
  of k8s clusters for their own needs.

* Managed k8s: The Operator's service team creates the capi management server and
  uses it to provide managed k8s clusters for their clients.

Note that we have an intermediate model in mind -- a model where a one-click / one-API
call interface would allow the management server to be created on behalf of a user
and then serve as an API endpoint to that user's k8s CAPI needs. Ideally with some
dashboard or GUI that would shield less experienced users from all the YAML.

Once we have the gitops style cluster control working, the self-service model
will become more convenient to use.

## Preparations

The preparations are done on a deployment host, possibly a tiny jumphost style VM,
or some Linux/MacOS/WSL laptop.

* Terraform must be installed (<https://learn.hashicorp.com/tutorials/terraform/install-cli>).
* You need to have `yq` (python3-yq or yq snap) and GNU make installed.
* You must have credentials to access the cloud. terraform will look for `clouds.yaml`
  and `secure.yaml` in the current working directory, in `~/.config/openstack/`
  and `/etc/openstack` (in this order), just like the openstack client.
  (<https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml>)
* Copy the environments sample file from environments/environment-default.tfvars to
  `environments/environment-<yourcloud>.tfvars` and provide the necessary information like
  machine flavor or machine image. You can comment out all lines where the defaults
  match your needs. (See below for more details on this.)
* Pass `ENVIRONMENT=<yourcloud>` to the `make` command or export `ENVIRONMENT` from
  your shell's environment. If the name of the environment equals the name of the cloud
  as specified in your `clouds.yaml`, you can also just set `OS_CLOUD` in your shell's
  environment. (You can also edit the default in the Makefile, though we don't recommend
  this.)

## Usage

* ``make create``

This will create the management server.
It creates an application credential, networks, security groups and a virtual machine
which gets bootstrapped with cloning this git repository, installation of some tool
and a local kubernetes cluster (with kind), where the cluster API provider will be
installed and which will provide the
API server for the k8s CAPI. If the number of control nodes ``controller_count`` in
your config (``environment-<yourcloud>.tfvars``) is zero, then that's all that is done.
Otherwise, a testcluster will be created using k8s CAPI.

The subsequent management of the cluster can best be done from the management server VM,
as it has all the tools deployed there and config files can be edited and resubmitted
to the kubernetes kind cluster for reconciliation. To log in to this management server
via ssh, you can issue ``make ssh``.

You can create and do life cycle management for many more clusters from this management server.

The kubeconfig with admin
power for the created testcluster is named ``testcluster/testcluster.yaml`` (or
``$CLUSTER_NAME/$CLUSTER_NAME.yaml`` for all the other clusters) and can be handed out to
users that should get full administrative control over the cluster. You can also retrieve
them using ``make get-kubeconfig TESTCLUSTER=${CLUSTER_NAME}`` from the machines where
you created the management server from, and possibly create an
encrypted .zip file for handing these out. (You can omit ``TESTCLUSTER=...`` for the
default testcluster.)

## Teardown

``make clean`` does ssh to the capi management server to clean up the created clusters prior
to terraform cleaning up the resources it has created. This is sometimes insufficient to clean up
unfortunately, some error in the deployment may result in resources left around.
``make fullclean`` uses a custom script (using the openstack CLI) to clean up everything
while trying to not hit any resources not created by the CAPI or terraform.
It is the recommended way for doing cleanups if ``make clean`` fails. Watch out for leftover
floating IP addresses and persistent volumes, as these can not be easily traced back to the
cluster-API created resources and may thus be left.

You can purge the whole project via ``make purge``. Be careful with that command as it will purge
*all resources in the OpenStack project* even those that have not been created through this
Terraform script or the cluster API.
It requires the [``ospurge``](https://opendev.org/x/ospurge) script.
Install it with ``python3 -m pip install git+https://git.openstack.org/openstack/ospurge``.

Note that ``clean`` and ``fullclean`` leave the ``ubuntu-capi-image-$KUBERNETES_VERSION`` image registered,
so it can be reused.
You need to manually unregister it, if you want your next deployment to register a new image with
the same kubernetes version number.

## Create a new cluster

On the management server (login with ``make ssh``), create a directory (below the home of
the standard ubuntu user) with the name of your cluster. Copy over ``clusterctl.yaml`` from
``~/cluster-defaults/`` and edit it according to your needs. You can also copy over other
files from ``~/cluster-defaults/`` and adjust them, but this is only needed in exceptional
cases.
Now run ``create_cluster.sh <CLUSTER_NAME>``

This will copy all missing defaults from ``~/cluster-defaults/`` into the directory with your
cluster name and then ask cluster-api to create the cluster. The scripts also take
care of security groups, anti-affinity, node image registration (if needed) and
of deploying CCM, CNI, CSI as well as optional services such as metrics or nginx-ingress
controller.

You can access the new cluster with ``kubectl --context clustername-admin@cluster``
or ``KUBECONFIG=~/clustername/clustername.yaml kubectl``.

The management cluster is in context ``kind-kind``.

Note that you can always change `clusterctl.yaml` and re-run `create_cluster.sh`.
The script is idempotent and running it multiple times with the unchanged input
file will result in no changes to the cluster.

## Troubleshooting

Please see the [Maintenance and Troubleshooting Guide](doc/Maintenance_and_Troubleshooting.md).

## Environments

for the plusserver community environment it can choose here:
``export ENVIRONMENT=gx-scs``

or insert inside of Makefile:
``ENVIRONMENT=gx-scs``

for the wavestack environment it can choose:
``export ENVIRONMENT=gx-wavestack``
 
or insert inside of Makefile:
``ENVIRONMENT=gx-wavestack``

a cloud.yaml and secure.yaml will be needed for the environments inside of terraform folder.

## Extensions (deprecated)

You can use this repository as a starting point for some automation e.g. adding
kubernetes manifests to the cluster or to run custom shell scripts in the end.
To do so place your files in the `terraform/extension` folder.  They will be
uploaded to the management server. Files ending in ```*.sh``` will be executed
in alphabetical order. All other files will just be uploaded. If you want to
deploy resources in the new cluster-api-maintained cluster you can use ``kubectl
apply -f <your-manifest.yaml> --kubeconfig ~/$CLUSTER_NAME/$CLUSTER_NAME.yaml`` to do so.

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
  breach easier to contain.
* AppCreds are connected to one project and can be revoked.

We are using an unrestricted AppCred for the management server which can then create
further AppCreds, so we can each cluster its own (restricted) credentials.
In the case of breaches, these AppCreds can be revoked.

Note that you can have additional projects or clouds listed in your
``~/.config/openstack/clouds.yaml`` (and ``secure.yaml``) and reference them
in the ``OPENSTACK_CLOUD`` setting of your ``clusterctl.yaml``, so you can
manage clusters in various projects and clouds from the same management server.

## Cluster Management on the capi management node

You can use ``make ssh`` to log in to the capi management server. There you can issue
``clusterctl`` and ``kubectl`` (aliased to ``k``) commands. The context ``kind-kind``
is used for the CAPI management while the context ``testcluster-admin@testcluster`` can
be used to control the workload cluster ``testcluster``. You can of course create many
of them. There are management scripts on the management server:

* In the user's (ubuntu) home directory, create a subdirectory with the CLUSTERNAME 
  to hold your cluster's configuration data. Copy over the `clusterctl.yaml` file
  from `~/cluster-defaults/` and edit it to meet your needs. Note that you can also
  copy over `cloud.conf` and `cluster-template.yaml` and adjust them, but you don't
  need to. (If you don't create the subdirectory, the `create_cluster.sh` script
  will do so for you and use all defaults settings.)
* ``create_cluster.sh CLUSTERNAME``: Use this command to create a cluster with
  the settings from ``~/$CLUSTERNAME/clusterctl.yaml``. More precisely, it uses the template
  ``$CLUSTERNAME/cluster-template.yaml`` and fills in the settings from
  ``$CLUSTERNAME/clusterctl.yaml`` to render a config file ``$CLUSTERNAME/$CLUSTERNAME-config.yaml``
  which will then be submitted to the capi server (``kind-kind`` context) for creating
  the control plane nodes and worker nodes. The script will also apply openstack integration,
  cinder CSI, calico or cilium CNI, and optionally also metrics server, nginx ingress controller,
  flux, cert-manager. (These can be controlled by `DEPLOY_XXX` variables, see below.
  Defaults can be preconfigured from the environment.tfvars file during management server
  creation.)
  Note that ``CLUSTERNAME`` defaults to ``testcluster`` and must not contain
  whitespace. 
  The script also makes sure that appropriate CAPI images are available (it grabs them
  from [OSISM](https://minio.services.osism.tech/openstack-k8s-capi-images)
  as needed and registers them with OpenStack, following the SCS image metadata
  standard).
  The script returns once the control plane is fully working (the worker
  nodes might still be under construction). The kubectl file to talk to this
  cluster (as admin) can be found in ``~/$CLUSTERNAME/$CLUSTERNAME.yaml``. Expect the cluster
  creation to take ~8mins. (CLUSTERNAME defaults to testcluster.) You can pass
  ``--context=${CLUSTERNAME}-admin@$CLUSTERNAME`` to ``kubectl`` (with the
  default ``~/.kubernetes/config`` config file) or ``export KUBECONFIG=$CLUSTERNAME.yaml``\
  to talk to the workload cluster.
* The subdirectory ``~/$CLUSTERNAME/deployed-manifests.d/`` will contain the
  deployed manifests for reference (and in case of nginx-ingress also to facilitate
  a full cleanup).
* The ``clusterctl.yaml`` file can be edited the ``create_cluster.sh`` script
  be called again to submit the changes. (If you have not done any changes,
  re-running the script again is harmless.) Note that the ``create_cluster.sh``
  does not currently remove any of the previously deployed services/deployments
  from the workload clusters -- this will be added later on with the appropriate
  care and warnings. Also note that not all changes are allowed. You can easily
  change the number of nodes or add k8s services to a cluster. For changing
  machine flavors, machine images, kubernetes versions ... you will need to
  also increase the ``CONTROL_PLANE_MACHINE_GEN`` or the ``WORKER_MACHINE_GEN``
  counter to add a different suffix to these read-only resources. This will
  cause Cluster-API to orchestrate a rolling upgrade for you on rollout.
  (This is solved more elegantly in the helm chart style cluster management, see below.)
* The directory ``~/k8s-cluster-api-provider/`` contains a checked out git tree
  from the SCS project. It can be updated (``git pull``) to receive the latest
  fixes and improvements. This way, most incremental updates do not need the
  recreation of the management server (and thus also not the recreation of your
  managed workload clusters), but can be applied with calling `create_cluster.sh`
  again to the workload clusters.
* The installation of the openstack integration, cinder CSI, metrics server and
  nginx ingress controller is done via the ``bin/apply_*.sh`` scripts that are called
  from ``create_cluster.sh``. You can manually call them as well -- they take
  the cluster name as argument. (It's better to just call `create_cluster.sh`
  again, though.) The applied yaml files are collected in
  ``~/$CLUSTERNAME/deployed-manifests.d/``. You can ``kubectl delete -f`` them
  to remove the functionality again.
* You can of course also delete the cluster and create a new one if that
  level of disruption is fine for you. (See below in Advanced cluster templating
  with helm to get an idea how we want to make this more convenient in the future.)
* Use ``kubectl get clusters`` in the ``kind-kind`` context to see what clusters
  exist. Use ``kubectl get all -A`` in the ``testcluster-admin@testcluster`` context
  to get an overview over the state of your workload cluster. You can access the logs
  from the capo controller in case you have trouble with cluster creation.
* ``delete_cluster.sh [CLUSTERNAME]``: Tell the capi management server to remove
  the cluster $CLUSTERNAME. It will also remove persistent volume claims belonging
  to the cluster. The script will return once the removal is done.
* ``cleanup.sh``: Remove all running clusters.
* `add_cluster-network.sh CLUSTERNAME` adds the management server to the node network
  of the cluster `CLUSTERNAME`, assuming that it runs on the same cloud (region).
  `remove_cluster-network.sh` undoes this again. This is useful for debugging
  purposes.

For your convenience, ``k9s`` is installed on the management server as well
as ``calicoctl``, ``cilium``, ``hubble``, ``cmctl``, ``helm`` and ``sonobuoy``.
These binaries can all be found in ``/usr/local/bin`` while the helper scripts
have been deployed to ``~/bin/``.

## Managing many clusters

While the scripts all use a default ``testcluster``, they have
been developed and tested to manage many clusters from a single management
node. Copy the ``~/cluster-defaults/clusterctl.yaml`` file to 
``~/MYCLUSTER/clusterctl.yaml``
and edit the copy to describe the properties of the cluster to be created.
Use ``./create_cluster.sh MYCLUSTER`` then to create a workload cluster
with the name ``MYCLUSTER``. You will find the kubeconfig file in
``~/MYCLUSTER/MYCLUSTER.yaml``, granting its owner admin access to that cluster.
Likewise, ``delete_cluster.sh`` and the ``apply_*.sh`` scripts take a
cluster name as parameter.

This way, dozens of clusters can be controlled from one management server.

You can add credentials from different projects into
``~/.config/openstack/clouds.yaml`` and reference them in the ``OPENSTACK_CLOUD``
setting in ``clusterctl.yaml``, this way managing clusters in many different
projects and even clouds from one management server.

## Testing

To test the created k8s cluster, there are several tools available.
Apply all commands to the testcluster context (by passing the appropriate
``--context`` setting to ``kubectl`` or by using the right ``KUBECONFIG``
file).

* Looking at all pods (``kubectl get pods -A``) to see that they all come
  up (and don't suffer excessive restarts) is a good first check.
  Look at the pod logs to investigate any failures.

* You can create a very simple deployment with the provided ``kuard.yaml``, which is
  an example taken from the O'Reilly book from B. Burns, J. Beda, K. Hightower:
  "Kubernetes Up & Running" enhanced to also use a persistent volume.

* You can deploy [Google's demo microservice application](https://github.com/GoogleCloudPlatform/microservices-demo).

* ``sonobuoy`` runs a subset of the k8s tests, providing a simple way to
  filter the >5000 existing test cases to only run the CNCF conformance
  tests or to restrict testing to non-disruptive tests. The ``sonobuoy.sh`` wrapper
  helps with calling it. There are also ``Makefile`` targets ``check-*`` that
  call various [sonobuoy](https://sonobuoy.io) test sets.
  This is how we call sonobuoy for our CI tests.

* You can use `cilium connectivity test` to check whether your cilium
  CNI is working properly. You might need to enable hubble to get
  a fully successful result.

## Supported k8s versions

As of 9/2022, our tests cover 1.21.latest ... 1.25.latest.
All of them pass the sonobuoy CNCF conformance tests.

## Upgrading from earlier versions

There is an upgrade guide in [doc/Upgrade-Guide.md](doc/Upgrade-Guide.md)

## etcd leader changes

While testing clusters with >= 3 control nodes, we have observed
occasional transient error messages that reported an etcd leader
change preventing a command from succeeding. This could result
in a dozen of random failed tests in a sonobuoy conformance run.
(Retrying the commands would let them succeed.)

Too frequent etcd leader changes are detrimental to your control
plane performance and can lead to transient failures. They are a sign
that the infrastructure supporting your cluster is introducing too high
latencies (>100ms in the default configuration which we don't change
by default, see below).

We recommend to deploy the control nodes (which run etcd) on instances
with local SSD storage (which we reflect in the default flavor name) and
recommend using flavors with dedicated cores and that
your network does not introduce latencies by significant packet drop.

We now always use slower heartbeat (250ms) and increase CPU and IO priority
which used to be controlled by `ETCD_PRIO_BOOST`. This is safe.

If you build multi-controller clusters and can not use a flavor with low
latency local storage (ideally SSD), you can also work around this with
`ETCD_UNSAFE_FS`. `ETCD_UNSAFE_FS` is using
`barrier=0` mount option, which violates filesystem ordering guarantees.
This works around storage latencies, but introduces the risk of inconsistent
filesystem state and inconsistent etcd data in case of an unclean shutdown.
You may be able to live with this risk in a multi-controller etcd setup.
If you don't have flavors that fulfill the requirements (low-latency
storage attached), your choice is between a single-controller cluster
(without `ETCD_UNSAFE_FS`) and a multi-controller cluster with
`ETCD_UNSAFE_FS`. Neither option is perfect, but we deem the
multi-controller cluster preferable in such a scenario.

## Multi-AZ and multi-cloud environments

The provided ``cluster-template.yaml`` assumes that all control nodes
on one hand and all worker nodes on the other are equal. They are in the
same cloud within the same availability zone, using the same flavor.
cluster API allows k8s clusters to have varying flavors, span availability
zones and even clouds. For this, you can create an advanced
cluster-template with more different machine descriptions and potentially
several secrets. Depending on your changes, the logic in ``create_cluster.sh``
might also need enhancements to handle this. Extending this is not hard
and we're happy to hear from your use cases and take patches.

However, we are currently investigating to use helm templating for anything
beyond the simple use cases instead, see next chapter.

## Advanced cluster templating with helm (Technical Preview)

On the management server, we have not only helm installed, but also the
repository [https://github.com/stackhpc/capi-helm-charts](https://github.com/stackhpc/capi-helm-charts)
checked out. Amongst other things, it automates the creation of new machine
templates when needed and doing rolling updates on your k8s cluster
with clusterctl. This allows for an easy adaptation of your cluster to
different requirements, new k8s versions etc.

Please note that this is currently evolving quickly and we have not
completely assessed and tested the capabilities. We intend to do
this after R2 and eventually recommend this as the standard way
of managing clusters in production. At this point, it's included as a
technical preview.

## Overview over the parameters in clusterctl.yaml and environment-XXX.tfvars

The provenance capo means that this setting comes from the templates used by
the cluster-api-provider-openstack, while SCS denotes that this setting has
been added by the SCS project.

Parameters controlling the Cluster-API management server (capi management server) creation:

| environment              | clusterctl.yaml | provenance | default        | meaning                                                                       |
|--------------------------|-----------------|------------|----------------|-------------------------------------------------------------------------------|
| `prefix`                 |                 | SCS        | `capi`         | Prefix used for OpenStack resources for the capi mgmt server                  |
| `kind_flavor`            |                 | SCS        | `SCS-1V:4:20`  | Flavor to be used for the k8s capi mgmt server                                |
| `image`                  |                 | SCS        | `Ubuntu 22.04` | Image to be deployed for the capi mgmt server                                 |
| `ssh_username`           |                 | SCS        | `ubuntu`       | Name of the default user for the `image`                                      |
| `clusterapi_version`     |                 | SCS        | `1.3.5`        | Version of the cluster-API incl. `clusterctl`                                 |
| `capi_openstack_version` |                 | SCS        | `0.7.1`        | Version of the cluster-api-provider-openstack (needs to fit the CAPI version) |

Parameters controlling both management server creation and cluster creation:

| environment         | clusterctl.yaml                 | provenance | default                              | meaning                                                                                                                      |
|---------------------|---------------------------------|------------|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| `cloud_provider`    | `OPENSTACK_CLOUD`               | capo       |                                      | `OS_CLOUD` name in clouds.yaml                                                                                               |
| `external`          | `OPENSTACK_EXTERNAL_NETWORK_ID` | capo       |                                      | Name/ID of the external (public) OpenStack network                                                                           |
| `dns_nameservers`   | `OPENSTACK_DNS_NAMESERVERS`     | capo       | `[ "5.1.66.255", "185.150.99.255" ]` | Array of nameservers for capi mgmt server and for cluster nodes, replace the FF MUC defaults with local servers if available |
| `availability_zone` | `OPENSTACK_FAILURE_DOMAIN`      | capo       |                                      | Availability Zone(s) for the mgmt node / workload clusters                                                                   |
| `kind_mtu`          | `MTU_VALUE`                     | SCS        | `0`                                  | MTU for the mgmt server; Calico is set 50 bytes smaller; 0 means autodetection                                               |

Parameters controlling the cluster creation:

| environment                      | clusterctl.yaml                           | provenance | default                                  | meaning                                                                                                                                                                                                    |
|----------------------------------|-------------------------------------------|------------|------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `node_cidr`                      | `NODE_CIDR`                               | SCS        | `10.8.0.0/20`                            | IPv4 address range (CIDR notation) for workload nodes                                                                                                                                                      |
| `use_cilium`                     | `USE_CILIUM`                              | SCS        | `false`                                  | Use cilium as CNI instead of calico                                                                                                                                                                        |
| `calico_version`                 |                                           | SCS        | `v3.25.0`                                | Version of the Calico CNI provider (ignored if `use_cilium` is set)                                                                                                                                        |
| `kubernetes_version`             | `KUBERNETES_VERSION`                      | capo       | `v1.25.x`                                | Kubernetes version deployed into workload cluster (`.x` means latest patch release)                                                                                                                        |
| ` `                              | `OPENSTACK_IMAGE_NAME`                    | capo       | `ubuntu-capi-image-${KUBERNETES_VERION}` | Image name for k8s controller and worker nodes                                                                                                                                                             |
| `kube_image_raw`                 | `OPENSTACK_IMAGE_RAW`                     | SCS        | `true`                                   | Register images in raw format (instead of qcow2), good for ceph COW                                                                                                                                        |
| `image_registration_extra_flags` | `OPENSTACK_IMAGE_REGISTATION_EXTRA_FLAGS` | SCS        | `""`                                     | Extra flags passed during image registration                                                                                                                                                               |
| ` `                              | `OPENSTACK_CONTROL_PLANE_IP`              | capo       | `127.0.0.1`                              | Use localhost to talk to capi cluster (don't change this!)                                                                                                                                                 |
| ` `                              | `OPENSTACK_SSH_KEY_NAME`                  | capo       | `${prefix}-keypair`                      | SSH key name generated and used to connect to workload cluster nodes                                                                                                                                       |
| `controller_flavor`              | `OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR`  | capo       | `SCS-2C:4:20s`                           | Flavor to be used for control plane nodes                                                                                                                                                                  |
| `worker_flavor`                  | `OPENSTACK_NODE_MACHINE_FLAVOR`           | capo       | `SCS-2V:4:20`                            | Flavor to be used for worker nodes                                                                                                                                                                         |
| `controller_count`               | `CONTROL_PLANE_MACHINE_COUNT`             | capo       | `1`                                      | Number of control plane nodes in testcluster (0 skips testcluster creation)                                                                                                                                |
| ` `                              | `CONTROL_PLANE_MACHINE_GEN`               | SCS        | `genc01`                                 | Suffix for control plane node resources, to be changed for rolling upgrades                                                                                                                                |
| `worker_count`                   | `WORKER_MACHINE_COUNT`                    | capo       | `3`                                      | Number of worker nodes in testcluster                                                                                                                                                                      |
| ` `                              | `WORKER_MACHINE_GEN`                      | SCS        | `genw01`                                 | Suffix for worker node resources, to be changed for rolling upgrades                                                                                                                                       |
| `anti_affinity`                  | `OPENSTACK_ANTI_AFFINITY`                 | SCS        | `true`                                   | Use anti-affinity server groups to prevent k8s nodes on same host (soft for workers, hard for controllers)                                                                                                 |
| ` `                              | `OPENSTACK_SRVGRP_CONTROLLER`             | SCS        | `nonono`                                 | Autogenerated if `anti_affinity` is `true`, eliminated otherwise                                                                                                                                           |
| ` `                              | `OPENSTACK_SRVGRP_WORKER`                 | SCS        | `nonono`                                 | Autogenerated if `anti_affinity` is `true`, eliminated otherwise                                                                                                                                           |
| `deploy_occm`                    | `DEPLOY_OCCM`                             | SCS        | `true`                                   | Deploy the given version of OCCM into the cluster. `true` (default) chooses the latest version matching the k8s version. You can specify `master` to chose the upstream master branch. Don't disable this. |
| `deploy_cindercsi`               | `DEPLOY_CINDERCSI`                        | SCS        | `true`                                   | Deploy the given (or latest matching for the default true value) of cinder CSI.                                                                                                                            |
| `etcd_unsafe_fs`                 | `ETCD_UNSAFE_FS`                          | SCS        | `false`                                  | Use `barrier=0` for filesystem on control nodes to avoid storage latency. Use for multi-controller clusters on slow/networked storage, otherwise not recommended.                                          |
| `testcluster_name`               | (cmd line)                                | SCS        | `testcluster`                            | Allows setting the default cluster name, created at bootstrap (if `controller_count` is larger than 0)                                                                                                     |
| `capo_instance_create_timeout`   | `CLUSTER_API_OPENSTACK_INSTANCE_CREATE_TIMEOUT`                                | SCS        | `10`                            | Time to wait for an OpenStack machine to be created (in minutes) |

Optional services deployed to cluster:

| environment            | clusterctl.yaml        | provenance | default | script                   | meaning                                                                                                                                                                                                                             |
|------------------------|------------------------|------------|---------|--------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `deploy_metrics`       | `DEPLOY_METRICS`       | SCS        | `true`  | `apply_metrics.sh`       | Deploy metrics service to nodes to make `kubectl top` work                                                                                                                                                                          |
| `deploy_nginx_ingress` | `DEPLOY_NGINX_INGRESS` | SCS        | `true`  | `apply_nginx_ingress.sh` | Deploy NGINX ingress controller (this spawns an OpenStack Loadbalancer), pass version to explicitly choose the version, `true` results in `v1.6.4` (`v1.0.2` for k8s <= 1.19)                                                       |
| ` `                    | `NGINX_INGRESS_PROXY`  | SCS        | `false` | (dito)                   | Configure LB and nginx to get real IP via PROXY protocol; may cause trouble for pod to LB connections.                                                                                                                              |
| `use_ovn_lb_provider`  | `USE_OVN_LB_PROVIDER`  | SCS        | `false` | `apply_nginx_ingress.sh` | Clouds using OVN networking can deploy the OVN provider that has low overhead (L3) and makes real client IPs visible without proxy protocol hacks. Set to `auto` to enable; not yet ready for prime time, thus defaults to `false`. |
| `deploy_cert_manager`  | `DEPLOY_CERT_MANAGER`  | SCS        | `false` | `apply_cert_manager.sh`  | Deploy cert-manager, pass version (e.g. `v1.11.0`) to explicitly choose a version                                                                                                                                                   |
| `deploy_flux`          | `DEPLOY_FLUX`          | SCS        | `false` |                          | Deploy flux2 into the cluster                                                                                                                                                                                                       |

## TODO (Highlights)

* Opt-in for per cluster project (extends [#109](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/109))
* Allow service deletion from `create_cluster.sh` ([#137](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/137), see also [#131](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/131))
* More pre-flight checks in `create_cluster.sh` ([#111](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/111)).
* Implement (optional) harbor deployment using k8s-harbor. ([#139](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/139))
* Move towards gitops style cluster management. (Design Doc in [Standards repo PR #47](https://github.com/SovereignCloudStack/standards/pull/47) - draft)

See also the [issues](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues) and
[PRs](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pulls) on GitHub.
