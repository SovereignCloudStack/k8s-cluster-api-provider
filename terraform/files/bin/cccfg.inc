# File to be included
. ~/.capi-settings
. ~/bin/yq.inc
# All three lines needed to support both orders for these parameters
if test "$1" == "--allow-preview-versions"; then export ALLOW_PREVIEW_VERSIONS=1; shift; fi
if test "$1" == "--allow-preview-features"; then export ALLOW_PREVIEW_FEATURES=1; shift; fi
if test "$1" == "--allow-preview-versions"; then export ALLOW_PREVIEW_VERSIONS=1; shift; fi
if test -n "$1"; then CLUSTER_NAME="${1%/}"; else CLUSTER_NAME="$TESTCLUSTER"; fi
export PREFIX CLUSTER_NAME
KUBECONFIG_WORKLOADCLUSTER="${HOME}/${CLUSTER_NAME}/${CLUSTER_NAME}.yaml"
if test -e "$HOME/${CLUSTER_NAME}/clusterctl.yaml"; then
	CCCFG="$HOME/${CLUSTER_NAME}/clusterctl.yaml"
else
	CCCFG=$HOME/cluster-defaults/clusterctl.yaml
fi
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
export OS_CLOUD=$(yq eval '.OPENSTACK_CLOUD' $CCCFG)

