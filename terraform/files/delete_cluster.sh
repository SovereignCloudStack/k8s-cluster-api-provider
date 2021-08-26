#!/bin/bash
# delete_cluster.sh [CLUSTERNAME]

if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
kubectl config use-context kind-kind
echo "Deleting cluster $CLUSTER_NAME"
kubectl delete cluster "$CLUSTER_NAME"
kubectl config delete-context "$CLUSTER_NAME-admin@$CLUSTER_NAME"
kubectl config delete-user "$CLUSTER_NAME-admin"
