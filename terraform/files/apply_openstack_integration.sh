#!/bin/bash
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=clusterctl.yaml; fi
#NAMESPACE=$(yq eval .NAMESPACE $CCCFG)
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}" # "--namespace=$NAMESPACE"

echo "Install external OpenStack cloud provider to $CLUSTER_NAME"
kubectl $KCONTEXT create secret generic cloud-config --from-file="$HOME"/cloud.conf -n kube-system #|| exit 6

# install external cloud-provider openstack
DEPLOY_K8S_OPENSTACK_GIT=$(yq eval '.DEPLOY_K8S_OPENSTACK_GIT' $CCCFG)
if test "$DEPLOY_K8S_OPENSTACK_GIT" = "true"; then
  for name in cloud-controller-manager-role-bindings.yaml cloud-controller-manager-roles.yaml openstack-cloud-controller-manager-ds.yaml openstack-cloud-controller-manager-pod.yaml; do
    if ! test -r $name; then
        curl -LO https://github.com/kubernetes/cloud-provider-openstack/raw/master/manifests/controller-manager/$name
	echo -e "\n---" >> $name
    fi
  done
  # Note: Do not deploy openstack-cloud-controller-manager-pod.yaml
  cat cloud-controller-manager*.yaml openstack-cloud-controller-manager-ds.yaml > openstack-git.yaml
  kubectl $KCONTEXT apply -f openstack-git.yaml || exit 7
else
  kubectl $KCONTEXT apply -f ~/openstack.yaml || exit 7
fi

