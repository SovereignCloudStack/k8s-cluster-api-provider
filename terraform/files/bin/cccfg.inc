# File to be included
CLUSTER_NAME=testcluster
if test -n "$1"; then CLUSTER_NAME="$1"; fi
KUBECONFIG_WORKLOADCLUSTER="${HOME}/${CLUSTER_NAME}/${CLUSTER_NAME}.yaml"
if test -e "$HOME/${CLUSTER_NAME}/clusterctl.yaml"; then
	CCCFG="$HOME/${CLUSTER_NAME}/clusterctl.yaml"
else
	CCCFG=$HOME/cluster-defaults/clusterctl.yaml
fi
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"

