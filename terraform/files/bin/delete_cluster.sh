#!/bin/bash
# delete_cluster.sh [CLUSTERNAME]
# (c) Kurt Garloff <garloff@osb-alliance.com>, 8/2021
# SPDX-License-Identifier: Apache-2.0

export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e ~/clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=~/clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=~/clusterctl.yaml; fi
kubectl config use-context kind-kind
echo "Deleting cluster $CLUSTER_NAME"
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
# Delete workload pods (default namespace)
PODS=$(kubectl $KCONTEXT get pods | grep -v '^NAME' | awk '{ print $1; }')
for pod in $PODS; do
	echo -en " Delete pod $pod\n "
	kubectl $KCONTEXT delete pod $pod
done
# Delete nginx ingress
INPODS=$(kubectl $KCONTEXT --namespace ingress-nginx get pods) 
if echo "$INPODS" | grep nginx >/dev/null 2>&1; then
	echo -en " Delete ingress \n "
	kubectl $KCONTEXT delete -f ~/kubernetes-manifests.d/nginx-ingress-controller.yaml
fi
# Delete persisten volumes
PVCS=$(kubectl $KCONTEXT get persistentvolumeclaims | grep -v '^NAME' | awk '{ print $1; }')
for pvc in $PVCS; do
	echo -en " Delete pvc $pvc\n "
	kubectl $KCONTEXT delete persistentvolumeclaim $pvc
done
# Delete server groups (if any)
if grep '^ *OPENSTACK_ANTI_AFFINITY: true' $CCCFG >/dev/null 2>&1; then
	SRVGRP=$(openstack server group list -f value)
	SRVGRP_CONTROLLER=$(echo "$SRVGRP" | grep "k8s-capi-${CLUSTER_NAME}-controller" | sed 's/^\([0-9a-f\-]*\) .*$/\1/')
	SRVGRP_WORKER=$(echo "$SRVGRP" | grep "k8s-capi-${CLUSTER_NAME}-worker" | sed 's/^\([0-9a-f\-]*\) .*$/\1/')
	if test -n "$SRVGRP_WORKER" -o -n "$SRVGRP_CONTROLLER"; then
		openstack server group delete $SRVGRP_WORKER $SRVGRP_CONTROLLER
	fi
fi
# Tell capi to clean up
sleep 1
kubectl delete cluster "$CLUSTER_NAME"
kubectl config delete-context "$CLUSTER_NAME-admin@$CLUSTER_NAME"
kubectl config delete-user "$CLUSTER_NAME-admin"
kubectl config delete-cluster "$CLUSTER_NAME"
openstack security group delete k8s-cluster-${CLUSTER_NAME}-cilium >/dev/null 2>&1 || true
