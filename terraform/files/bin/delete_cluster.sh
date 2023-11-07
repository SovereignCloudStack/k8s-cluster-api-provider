#!/bin/bash
# delete_cluster.sh [CLUSTERNAME]
# (c) Kurt Garloff <garloff@osb-alliance.com>, 8/2021
# SPDX-License-Identifier: Apache-2.0

export KUBECONFIG=~/.kube/config
. ~/.capi-settings
. ~/bin/cccfg.inc

CREATE_NEW_NAMESPACE=false . ~/bin/mng_cluster_ns.inc

echo "Deleting cluster $CLUSTER_NAME"
# Cordoning all nodes
echo "Cordoning all nodes ..."
kubectl $KCONTEXT get nodes -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT cordon '}{.metadata.name}{'\n'}{end}" | bash
# Delete storage classes (prevents creation of new PVs)
echo "Deleting storage classes ..."
kubectl $KCONTEXT get storageclasses -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete storageclass '}{.metadata.name}{' --ignore-not-found=true\n'}{end}" | bash
# Delete nginx ingress
INPODS=$(kubectl $KCONTEXT --namespace ingress-nginx get pods)
if echo "$INPODS" | grep nginx >/dev/null 2>&1; then
	echo -en " Delete ingress \n "
	timeout 150 kubectl $KCONTEXT delete -f ~/${CLUSTER_NAME}/deployed-manifests.d/nginx-ingress.yaml
fi
# Delete deployments with persistent volume claims
echo "Deleting deployments with persistent volume claims ..."
kubectl $KCONTEXT get deployments --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[?(@.spec.template.spec.volumes[*].persistentVolumeClaim.claimName)]}{'kubectl $KCONTEXT delete deployment '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
# Delete daemonsets with persistent volume claims
echo "Deleting daemonsets with persistent volume claims ..."
kubectl $KCONTEXT get daemonsets --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[?(@.spec.template.spec.volumes[*].persistentVolumeClaim.claimName)]}{'kubectl $KCONTEXT delete daemonset '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
# Delete statefulsets with persistent volume claims
echo "Deleting statefulsets with persistent volume claims ..."
kubectl $KCONTEXT get statefulsets --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[?(@.spec.template.spec.volumes[*].persistentVolumeClaim.claimName)]}{'kubectl $KCONTEXT delete statefulset '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
# Delete all CronJobs
echo "Deleting all CronJobs ..."
kubectl $KCONTEXT get cronjobs --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete cronjob '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --force\n'}{end}" | bash
# Delete all Jobs
echo "Deleting all Jobs ..."
kubectl $KCONTEXT get jobs --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete job '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --force\n'}{end}" | bash
# Delete pods with persistent volume claims
echo "Deleting pods with persistent volume claims ..."
kubectl $KCONTEXT get pods --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[?(@.spec.volumes[*].persistentVolumeClaim.claimName)]}{'kubectl $KCONTEXT delete pod '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
# Delete persistent volume claims
echo "Delete persistent volume claims"
kubectl $KCONTEXT get pvc --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete pvc '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true --wait\n'}{end}" | bash
# Delete Persistent Volumes
echo "Deleting all Persistent Volumes..."
kubectl $KCONTEXT get pv -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete pv '}{.metadata.name}{'  --grace-period=0 --ignore-not-found=true --wait\n'}{end}" | bash
# Delete all deployments
echo "Deleting all deployments ..."
kubectl $KCONTEXT get deployments --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete deployment '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
# Delete all daemonsets
echo "Deleting all daemonsets ..."
kubectl $KCONTEXT get daemonsets --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete daemonset '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
# Delete all statefulsets
echo "Deleting all statefulsets ..."
kubectl $KCONTEXT get statefulsets --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete statefulset '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
# Delete workload pods
echo "Deleting pods ..."
kubectl $KCONTEXT get pods --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete pod '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
# Delete all Ingress
echo "Deleting all Ingress ..."
kubectl $KCONTEXT get ingress --all-namespaces -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete ingress '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
# Delete all Services (except `kubernetes` service in `default` namespace)
echo "Deleting all Services ..."
kubectl $KCONTEXT get services --all-namespaces --field-selector metadata.name!=kubernetes -o=jsonpath="{'set -x\n'}{range .items[*]}{'kubectl $KCONTEXT delete service '}{.metadata.name}{' -n '}{.metadata.namespace}{' --grace-period=0 --ignore-not-found=true\n'}{end}" | bash
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
	PORTS=$(openstack port list --fixed-ip subnet=k8s-clusterapi-cluster-$CLUSTER_NAMESPACE-$CLUSTER_NAME -f value -c Id -c Status -c fixed_ips)
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
kubectl config set-context --current --namespace=default
if [[ $CLUSTER_NAMESPACE != default ]]; then
  kubectl delete namespace "$CLUSTER_NAMESPACE"
fi
# Clean up harbor
if [ -f "$HOME/$CLUSTER_NAME/deployed-manifests.d/harbor/.ec2" ]; then
  . $HOME/$CLUSTER_NAME/deployed-manifests.d/harbor/.ec2
  echo "Deleting ec2 credentials $REGISTRY_STORAGE_S3_ACCESSKEY"
  openstack ec2 credentials delete $REGISTRY_STORAGE_S3_ACCESSKEY
  HARBOR_S3_BUCKET=$PREFIX-$CLUSTER_NAME-harbor-registry
  echo "Deleting bucket $HARBOR_S3_BUCKET"
  openstack container delete $HARBOR_S3_BUCKET
fi
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
rm -rf ~/$CLUSTER_NAME
if test $RC = 0; then
  echo "Deleting cluster $CLUSTER_NAME completed successfully."
else
  echo "Deleting cluster $CLUSTER_NAME likely incomplete."
fi
exit $RC
