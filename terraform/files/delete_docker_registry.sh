#!/bin/bash
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
#NAMESPACE=$(yq eval .NAMESPACE $CCCFG)
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}" # "--namespace=$NAMESPACE"
#
kubectl $KCONTEXT delete -f docker-registry-pod.yaml
kubectl $KCONTEXT delete -f repository-volume.yaml
