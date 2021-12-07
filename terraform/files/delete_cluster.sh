#!/bin/bash
# delete_cluster.sh [CLUSTERNAME]
# (c) Kurt Garloff <garloff@osb-alliance.com>, 8/2021
# SPDX-License-Identifier: Apache-2.0

export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=clusterctl.yaml; fi
NAMESPACE=$(yq eval .NAMESPACE $CCCFG)
kubectl config use-context kind-kind
echo "Deleting cluster $CLUSTER_NAME"
KCONTEXTNS="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME} --namespace=$NAMESPACE"
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
# Delete workload pods (default namespace)
PODS=$(kubectl $KCONTEXTNS get pods | grep -v '^NAME' | awk '{ print $1; }')
for pod in $PODS; do
	echo -en " Delete pod $pod\n "
	kubectl $KCONTEXTNS delete pod $pod
done
# Delete nginx ingress
INPODS=$(kubectl $KCONTEXT --namespace ingress-nginx get pods) 
if echo "$INPODS" | grep nginx >/dev/null 2>&1; then
	echo -en " Delete ingress \n "
	kubectl $KCONTEXT delete -f nginx-ingress-controller.yaml
fi
# Delete persisten volumes
PVCS=$(kubectl $KCONTEXTNS get persistentvolumeclaims | grep -v '^NAME' | awk '{ print $1; }')
for pvc in $PVCS; do
	echo -en " Delete pvc $pvc\n "
	kubectl $KCONTEXTNS delete persistentvolumeclaim $pvc
done
sleep 1
kubectl delete cluster "$CLUSTER_NAME"
kubectl config delete-context "$CLUSTER_NAME-admin@$CLUSTER_NAME"
kubectl config delete-user "$CLUSTER_NAME-admin"
kubectl config delete-cluster "$CLUSTER_NAME"
