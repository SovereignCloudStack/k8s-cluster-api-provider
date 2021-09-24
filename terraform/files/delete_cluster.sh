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
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME} --namespace=$NAMESPACE"
PODS=$(kubectl $KCONTEXT get pods | grep -v '^NAME' | awk '{ print $1; }')
for pod in $PODS; do
	echo -en " Delete pod $pod\n "
	kubectl $KCONTEXT delete pod $pod
done
PVCS=$(kubectl $KCONTEXT get persistentvolumeclaims | grep -v '^NAME' | awk '{ print $1; }')
for pvc in $PVCS; do
	echo -en " Delete pvc $pvc\n "
	kubectl $KCONTEXT delete persistentvolumeclaim $pvc
done
# TODO: Loadbalancers
sleep 1
kubectl delete cluster "$CLUSTER_NAME"
kubectl config delete-context "$CLUSTER_NAME-admin@$CLUSTER_NAME"
kubectl config delete-user "$CLUSTER_NAME-admin"
kubectl config delete-cluster "$CLUSTER_NAME"
