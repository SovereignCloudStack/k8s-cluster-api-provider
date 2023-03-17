# Managing many clusters

While the scripts all use a default `testcluster`, they have
been developed and tested to manage many clusters from a single management
node. Copy the `~/cluster-defaults/clusterctl.yaml` file to
`~/MYCLUSTER/clusterctl.yaml`
and edit the copy to describe the properties of the cluster to be created.
Use `./create_cluster.sh MYCLUSTER` then to create a workload cluster
with the name `MYCLUSTER`. You will find the kubeconfig file in
`~/MYCLUSTER/MYCLUSTER.yaml`, granting its owner admin access to that cluster.
Likewise, `delete_cluster.sh` and the `apply_*.sh` scripts take a
cluster name as parameter.

This way, dozens of clusters can be controlled from one management server.

You can add credentials from different projects into
`~/.config/openstack/clouds.yaml` and reference them in the `OPENSTACK_CLOUD`
setting in `clusterctl.yaml`, this way managing clusters in many different
projects and even clouds from one management server.
