#!/bin/bash
# delete_cluster.sh [CLUSTERNAME]
# (c) Kurt Garloff <garloff@osb-alliance.com>, 8/2021
# SPDX-License-Identifier: Apache-2.0

export KUBECONFIG=~/.kube/config
. ~/.capi-settings
. ~/bin/cccfg.inc

kubectl config set-context kind-kind --namespace $CLUSTER_NAME || exit 1
kubectl config use-context kind-kind || exit 1
echo "Deleting cluster $CLUSTER_NAME"
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
	timeout 150 kubectl $KCONTEXT delete -f ~/${CLUSTER_NAME}/deployed-manifests.d/nginx-ingress.yaml
fi
# Delete persistent volumes
PVCS=$(kubectl $KCONTEXT get persistentvolumeclaims | grep -v '^NAME' | awk '{ print $1; }')
for pvc in $PVCS; do
	echo -en " Delete pvc $pvc\n "
	kubectl $KCONTEXT delete persistentvolumeclaim $pvc
done
# Delete server groups (if any)
if grep '^ *OPENSTACK_ANTI_AFFINITY: true' $CCCFG >/dev/null 2>&1; then
	SRVGRP=$(openstack server group list -f value)
	SRVGRP_CONTROLLER=$(echo "$SRVGRP" | grep "${PREFIX}-${CLUSTER_NAME}-controller" | sed 's/^\([0-9a-f\-]*\) .*$/\1/')
	SRVGRP_WORKER=$(echo "$SRVGRP" | grep "${PREFIX}-${CLUSTER_NAME}-worker" | sed 's/^\([0-9a-f\-]*\) .*$/\1/')
	if test -n "$SRVGRP_WORKER" -o -n "$SRVGRP_CONTROLLER"; then
		openstack server group delete $SRVGRP_WORKER $SRVGRP_CONTROLLER
	fi
fi
# Detach network interface (if ever attached)
remove_cluster-network.sh "$CLUSTER_NAME" >/dev/null || true
# Tell capi to clean up
# TODO: Do this with timeout, possibly do some additional diagnostics to help with clean up
timeout 150 kubectl delete cluster "$CLUSTER_NAME"
RC=$?
kubectl config delete-context "$CLUSTER_NAME-admin@$CLUSTER_NAME"
kubectl config delete-user "$CLUSTER_NAME-admin"
kubectl config delete-cluster "$CLUSTER_NAME"
if test $RC != 0; then
	PORTS=$(openstack port list --fixed-ip subnet=k8s-clusterapi-cluster-default-$CLUSTER_NAME -f value -c Id -c Status -c fixed_ips)
	NODE_CIDR=$(grep NODE_CIDR ~/$CLUSTER_NAME/clusterctl.yaml | sed 's/^NODE_CIDR: *//')
	NODE_START=${NODE_CIDR%.*}; NODE_START=${NODE_START%.*}
	while read id stat fixed; do
		if test "$stat" != "DOWN"; then continue; fi
		ADR=$(echo "$fixed" | sed "s/^.*ip_address': '\([0-9\.]*\)'.*\$/\1/")
		ADR_START="${ADR%.*}"; ADR_START="${ADR_START%.*}"
		if test "$NODE_START" != "$ADR_START"; then continue; fi
		ADR_END="${ADR#$ADR_START.}"
		if test "$ADR_END" = "0.1" -o "$ADR_END" = "0.2"; then continue; fi
		echo "Clean up port $id ($ADR) ..."
		openstack port delete $id
	done < <(echo "$PORTS")
fi
openstack security group delete ${PREFIX}-${CLUSTER_NAME}-cilium >/dev/null 2>&1 || true
if test $RC != 0; then
	timeout 150 kubectl delete cluster "$CLUSTER_NAME"
	# Non existent cluster means success
	if ! kubectl get cluster "$CLUSTER_NAME"; then RC=0; fi
fi
kubectl delete namespace "$CLUSTER_NAME"
# TODO: Clean up machine templates etc.
# Clean up appcred stuff (for new style appcred mgmt)
if grep '^OLD_OPENSTACK_CLOUD:' $CCCFG >/dev/null 2>&1; then
  # Remove from clouds.yaml
  mkdir -p ~/tmp
  echo "Removing application credential $PREFIX-$CLUSTER_NAME-appcred ..."
  OS_CLOUD="$PREFIX-$CLUSTER_NAME" print-cloud.py -x -s >~/tmp/clouds-no-$OS_CLOUD.yaml || exit 5
  cp -p ~/.config/openstack/clouds.yaml ~/.config/openstack/clouds.yaml.$OS_CLOUD
  mv ~/tmp/clouds-no-$OS_CLOUD.yaml ~/.config/openstack/clouds.yaml
  # Restore old OS_CLOUD
  sed -i '/^OPENSTACK_CLOUD:/d' $CCCFG; sed -i 's/^OLD_OPENSTACK_CLOUD:/OPENSTACK_CLOUD:/' $CCCFG
  # Delete app cred
  OS_CLOUD=$(yq eval '.OPENSTACK_CLOUD' $CCCFG)
  if test $RC = 0; then
    openstack application credential delete "$PREFIX-$CLUSTER_NAME-appcred" || RC=1
  else
    echo "Please delete application credential $PREFIX-$CLUSTER_NAME-appcred once capo has cleaned everything up."
  fi
fi
# TODO: Clean up ~/$CLUSTER_NAME
exit $RC
