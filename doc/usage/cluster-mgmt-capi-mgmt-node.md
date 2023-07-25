# Cluster Management on the capi management node

You can use `make ssh` to log in to the capi management server. There you can issue`clusterctl` and `kubectl` (aliased
to `k`) commands. The context `kind-kind`
is used for the CAPI management while the context `testcluster-admin@testcluster` can
be used to control the workload cluster `testcluster`. You can of course create many
of them. There are management scripts on the management server:

- In the user's (ubuntu) home directory, create a subdirectory with the CLUSTERNAME
  to hold your cluster's configuration data. Copy over the `clusterctl.yaml` file
  from `~/cluster-defaults/` and edit it to meet your needs. Note that you can also
  copy over `cloud.conf` and `cluster-template.yaml` and adjust them, but you don't
  need to. (If you don't create the subdirectory, the `create_cluster.sh` script
  will do so for you and use all defaults settings.)
- `create_cluster.sh CLUSTERNAME`: Use this command to create a cluster with
  the settings from `~/$CLUSTERNAME/clusterctl.yaml`. More precisely, it uses the template
  `$CLUSTERNAME/cluster-template.yaml` and fills in the settings from
  `$CLUSTERNAME/clusterctl.yaml` to render a config file `$CLUSTERNAME/$CLUSTERNAME-config.yaml`
  which will then be submitted to the capi server (`kind-kind` context) for creating
  the control plane nodes and worker nodes. The script will also apply openstack integration,
  cinder CSI, calico or cilium CNI, and optionally also metrics server, nginx ingress controller,
  flux, cert-manager. (These can be controlled by `DEPLOY_XXX` variables, see below.
  Defaults can be preconfigured from the environment.tfvars file during management server
  creation.)
  Note that `CLUSTERNAME` defaults to `testcluster` and must not contain
  whitespace.
  The script also makes sure that appropriate CAPI images are available (it grabs them
  from [OSISM](https://minio.services.osism.tech/openstack-k8s-capi-images)
  as needed and registers them with OpenStack, following the SCS image metadata
  standard).
  The script returns once the control plane is fully working (the worker
  nodes might still be under construction). The kubectl file to talk to this
  cluster (as admin) can be found in `~/$CLUSTERNAME/$CLUSTERNAME.yaml`. Expect the cluster
  creation to take ~8mins. (CLUSTERNAME defaults to testcluster.) You can pass
  `--context=${CLUSTERNAME}-admin@$CLUSTERNAME` to `kubectl` (with the
  default `~/.kubernetes/config` config file) or `export KUBECONFIG=$CLUSTERNAME.yaml`\
  to talk to the workload cluster.
- The subdirectory `~/$CLUSTERNAME/deployed-manifests.d/` will contain the
  deployed manifests for reference (and in case of nginx-ingress also to facilitate
  a full cleanup).
- The `clusterctl.yaml` file can be edited the `create_cluster.sh` script
  be called again to submit the changes. (If you have not done any changes,
  re-running the script again is harmless.) Note that the `create_cluster.sh`
  does not currently remove any of the previously deployed services/deployments
  from the workload clusters -- this will be added later on with the appropriate
  care and warnings. Also note that not all changes are allowed. You can easily
  change the number of nodes or add k8s services to a cluster. For changing
  machine flavors, machine images, kubernetes versions ... you will need to
  also increase the `CONTROL_PLANE_MACHINE_GEN` or the `WORKER_MACHINE_GEN`
  counter to add a different suffix to these read-only resources. This will
  cause Cluster-API to orchestrate a rolling upgrade for you on rollout.
  (This is solved more elegantly in the helm chart style cluster management, see below.)
- The directory `~/k8s-cluster-api-provider/` contains a checked out git tree
  from the SCS project. It can be updated (`git pull`) to receive the latest
  fixes and improvements. This way, most incremental updates do not need the
  recreation of the management server (and thus also not the recreation of your
  managed workload clusters), but can be applied with calling `create_cluster.sh`
  again to the workload clusters.
- The installation of the openstack integration, cinder CSI, metrics server and
  nginx ingress controller is done via the `bin/apply_*.sh` scripts that are called
  from `create_cluster.sh`. You can manually call them as well -- they take
  the cluster name as argument. (It's better to just call `create_cluster.sh`
  again, though.) The applied yaml files are collected in
  `~/$CLUSTERNAME/deployed-manifests.d/`. You can `kubectl delete -f` them
  to remove the functionality again.
- You can of course also delete the cluster and create a new one if that
  level of disruption is fine for you. (See below in Advanced cluster templating
  with helm to get an idea how we want to make this more convenient in the future.)
- Use `kubectl get clusters` in the `kind-kind` context to see what clusters
  exist. Use `kubectl get all -A` in the `testcluster-admin@testcluster` context
  to get an overview over the state of your workload cluster. You can access the logs
  from the capo controller in case you have trouble with cluster creation.
- `delete_cluster.sh [CLUSTERNAME]`: Tell the capi management server to remove
  the cluster $CLUSTERNAME. It will also remove persistent volume claims belonging
  to the cluster. The script will return once the removal is done.
- `cleanup.sh`: Remove all running clusters.
- `add_cluster-network.sh CLUSTERNAME` adds the management server to the node network
  of the cluster `CLUSTERNAME`, assuming that it runs on the same cloud (a region).
  `remove_cluster-network.sh` undoes this again. This is useful for debugging
  purposes.

For your convenience, `k9s` is installed on the management server as well
as `calicoctl`, `cilium`, `hubble`, `cmctl`, `helm` and `sonobuoy`.
These binaries can all be found in `/usr/local/bin` while the helper scripts
have been deployed to `~/bin/`.
