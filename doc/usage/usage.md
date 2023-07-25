# Usage

The subsequent management of the cluster can best be done from the management server VM, as it has all the tools
deployed there and config files can be edited and resubmitted to the kubernetes kind cluster for reconciliation. To log
in to this management server via ssh, you can issue `make ssh`.

You can create and do life cycle management for many more clusters from this management server.

The kubeconfig with admin power for the created testcluster is named `testcluster/testcluster.yaml` (
or `$CLUSTER_NAME/$CLUSTER_NAME.yaml` for all the other clusters) and can be handed out to users that should get full
administrative control over the cluster. You can also retrieve them
using `make get-kubeconfig TESTCLUSTER=${CLUSTER_NAME}` from the machines where you created the management server from,
and possibly create an encrypted .zip file for handing these out. (You can omit `
