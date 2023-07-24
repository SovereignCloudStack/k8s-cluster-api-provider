# Create a new cluster

On the management server (login with `make ssh`), create a directory (below the home of
the standard ubuntu user) with the name of your cluster. Copy over `clusterctl.yaml` from
`~/cluster-defaults/` and edit it according to your needs. You can also copy over other
files from `~/cluster-defaults/` and adjust them, but this is only needed in exceptional
cases.
Now run `create_cluster.sh <CLUSTER_NAME>`

This will copy all missing defaults from `~/cluster-defaults/` into the directory with your
cluster name and then ask cluster-api to create the cluster. The scripts also take
care of security groups, anti-affinity, node image registration (if needed) and
of deploying CCM, CNI, CSI as well as optional services such as metrics or nginx-ingress
controller.

You can access the new cluster with `kubectl --context clustername-admin@cluster`
or `KUBECONFIG=~/clustername/clustername.yaml kubectl`.

The management cluster is in context `kind-kind`.

Note that you can always change `clusterctl.yaml` and re-run `create_cluster.sh`. The script is idempotent and running
it multiple times with the unchanged input file will result in no changes to the cluster.
