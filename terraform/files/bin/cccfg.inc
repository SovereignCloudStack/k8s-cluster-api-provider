# File to be included
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
export CLUSTER_NAME
KUBECONFIG_WORKLOADCLUSTER="${HOME}/${CLUSTER_NAME}/${CLUSTER_NAME}.yaml"
if test -e "$HOME/${CLUSTER_NAME}/clusterctl.yaml"; then
	CCCFG="$HOME/${CLUSTER_NAME}/clusterctl.yaml"
else
	CCCFG=$HOME/cluster-defaults/clusterctl.yaml
fi
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
export OS_CLOUD=$(yq eval '.OPENSTACK_CLOUD' $CCCFG)

