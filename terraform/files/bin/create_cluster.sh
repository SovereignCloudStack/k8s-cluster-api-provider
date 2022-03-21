#!/usr/bin/env bash

##    desc: a helper for deploy a workload cluster on mgmt cluster
## license: Apache-2.0

STARTTIME=$(date +%s)
# variables
. ~/.capi-settings
. ~/bin/cccfg.inc

# Ensure directory for cluster exists
if test ! -d ~/$CLUSTER_NAME; then 
	mkdir -p ~/$CLUSTER_NAME
	cp -p ~/cluster-defaults/* ~/$CLUSTER_NAME/
fi
# Copy missing files individually as needed from cluster-defaults
if test ! -s ~/$CLUSTER_NAME/cloud.conf; then
	cp -p ~/cluster-defaults/cloud.conf ~/$CLUSTER_NAME/
fi
CLUSTERAPI_TEMPLATE=~/${CLUSTER_NAME}/cluster-template.yaml
if test ! -s $CLUSTERAPI_TEMPLATE; then
	cp -p ~/cluster-defaults/cluster-template.yaml ~/$CLUSTER_NAME/
fi
if test ! -d ~/$CLUSTER_NAME/deployed-manifests.d/; then
	mkdir -p ~/$CLUSTER_NAME/deployed-manifests.d/
fi
CCCFG="$HOME/${CLUSTER_NAME}/clusterctl.yaml"
fixup_k8s_version.sh $CCCFG

#export OS_CLOUD=$(yq eval '.OPENSTACK_CLOUD' $CCCFG)
# Ensure image is there
wait_capi_image.sh "$1" || exit 1

# Switch to capi mgmt cluster
export KUBECONFIG=$HOME/.kube/config
kubectl config use-context kind-kind || exit 1
# get the needed clusterapi-variables
echo "# show used variables for clustertemplate ${CLUSTERAPI_TEMPLATE}"

# TODO: Optional: Create own project for the cluster
# If so, we need to share the image with the new project

# TODO: Create pre-cluster app-creds:
# (1) For CAPO
# (2) For OCCM, CSI

# Implement anti-affinity with server groups
if grep '^ *OPENSTACK_ANTI_AFFINITY: true' $CCCFG >/dev/null 2>&1; then
	SRVGRP=$(openstack server group list -f value)
	SRVGRP_CONTROLLER=$(echo "$SRVGRP" | grep "k8s-capi-${CLUSTER_NAME}-controller" | sed 's/^\([0-9a-f\-]*\) .*$/\1/')
	SRVGRP_WORKER=$(echo "$SRVGRP" | grep "k8s-capi-${CLUSTER_NAME}-worker" | sed 's/^\([0-9a-f\-]*\) .*$/\1/')
	if test -z "$SRVGRP_CONTROLLER"; then
		SRVGRP_CONTROLLER=$(openstack --os-compute-api-version 2.15 server group create --policy anti-affinity -f value -c id k8s-capi-${CLUSTER_NAME}-controller)
		SRVGRP_WORKER=$(openstack --os-compute-api-version 2.15 server group create --policy soft-anti-affinity -f value -c id k8s-capi-${CLUSTER_NAME}-worker)
	fi
	echo "Adding server groups $SRVGRP_CONTROLLER and $SRVGRP_WORKER to $CCCFG"
	if test -n "$SRVGRP_CONTROLLER"; then
		sed -i "s/^\(OPENSTACK_SRVGRP_CONTROLLER:\).*\$/\1 $SRVGRP_CONTROLLER/" "$CCCFG"
	fi
	if test -n "$SRVGRP_WORKER"; then
		sed -i "s/^\(OPENSTACK_SRVGRP_WORKER:\).*\$/\1 $SRVGRP_WORKER/" "$CCCFG"
	fi
fi

cp -p "$CCCFG" $HOME/.cluster-api/clusterctl.yaml
#clusterctl config cluster ${CLUSTER_NAME} --list-variables --from ${CLUSTERAPI_TEMPLATE}
clusterctl generate cluster "${CLUSTER_NAME}" --list-variables --from ${CLUSTERAPI_TEMPLATE} || exit 2

# the needed variables are read from $HOME/.cluster-api/clusterctl.yaml
echo "# rendering clusterconfig from template"
unset CLUSTER_EXISTS
if test -e ~/${CLUSTER_NAME}/${CLUSTER_NAME}-config.yaml; then
	echo " Overwriting config for ${CLUSTER_NAME}"
	CLUSTERS=$(kubectl get clusters | grep -v '^NAME' | grep "^$CLUSTER_NAME " | awk '{ print $1; }')
	if test -n "$CLUSTERS"; then
		export CLUSTER_EXISTS=1
		echo -e " Warning: Cluster exists\n Hit ^C to interrupt"
		sleep 6
	fi
fi
#clusterctl config cluster ${CLUSTER_NAME} --from ${CLUSTERAPI_TEMPLATE} > rendered-${CLUSTERAPI_TEMPLATE}
clusterctl generate cluster "${CLUSTER_NAME}" --from ${CLUSTERAPI_TEMPLATE} > ~/${CLUSTER_NAME}/${CLUSTER_NAME}-config.yaml
# Remove empty serverGroupID
sed -i '/^ *serverGroupID: nonono$/d' ~/${CLUSTER_NAME}/${CLUSTER_NAME}-config.yaml

# Test for CILIUM
USE_CILIUM=$(yq eval '.USE_CILIUM' $CCCFG)
if test "$USE_CILIUM" = "true"; then
	echo "# Security groups for cilium"
	enable-cilium-sg.sh "$CLUSTER_NAME"
else
	sed -i '/\-cilium$/d' ~/${CLUSTER_NAME}/${CLUSTER_NAME}-config.yaml
fi

# apply to the kubernetes mgmt cluster
echo "# apply configuration and deploy cluster ${CLUSTER_NAME}"
kubectl apply -f ~/${CLUSTER_NAME}/${CLUSTER_NAME}-config.yaml || exit 3

#Waiting for Clusterstate Ready
echo "# Waiting for Cluster=Ready"
#wget https://gx-scs.okeanos.dev --quiet -O /dev/null
#ping -c1 -w2 9.9.9.9 >/dev/null 2>&1
if test "$CLUSTER_EXISTS" = "1"; then sleep 12; fi
kubectl wait --timeout=5s --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} >/dev/null 2>&1 || sleep 25
kubectl wait --timeout=15m --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} || exit 1
kubectl wait --timeout=5m --for=condition=Ready machine -l cluster.x-k8s.io/control-plane || exit 4

kubectl get secrets "${CLUSTER_NAME}-kubeconfig" --output go-template='{{ .data.value | base64decode }}' > "${KUBECONFIG_WORKLOADCLUSTER}" || exit 5
chmod 0600 "${KUBECONFIG_WORKLOADCLUSTER}"
echo "INFO: kubeconfig for ${CLUSTER_NAME} in ${KUBECONFIG_WORKLOADCLUSTER}"
export KUBECONFIG="$HOME/.kube/config:${KUBECONFIG_WORKLOADCLUSTER}"
MERGED=$(mktemp merged.yaml.XXXXXX)
kubectl config view --flatten > $MERGED
mv $MERGED $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"

SLEEP=0
until kubectl $KCONTEXT api-resources
do
    echo "[$SLEEP] waiting for api-server"
    sleep 10
    let SLEEP+=10
done

# CNI
echo "# Deploy services (CNI, OCCM, CSI, Metrics, Cert-Manager, Flux2, Ingress"
MTU_VALUE=$(yq eval '.MTU_VALUE' $CCCFG)
if test "$USE_CILIUM" = "true"; then
  # FIXME: Do we need to allow overriding MTU here as well?
  KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} cilium install
  touch ~/$CLUSTER_NAME/deployed-manifests.d/.cilium
else
  sed "s/\(veth_mtu.\).*/\1 \"${MTU_VALUE}\"/g" ~/kubernetes-manifests.d/calico.yaml > ~/$CLUSTER_NAME/deployed-manifests.d/calico.yaml
  kubectl $KCONTEXT apply -f ~/$CLUSTER_NAME/deployed-manifests.d/calico.yaml
fi

# OpenStack, Cinder
apply_openstack_integration.sh "$CLUSTER_NAME" || exit $?
apply_cindercsi.sh "$CLUSTER_NAME" || exit $?

# Metrics
DEPLOY_METRICS=$(yq eval '.DEPLOY_METRICS' $CCCFG)
if test "$DEPLOY_METRICS" = "true"; then
  apply_metrics.sh "$CLUSTER_NAME" || exit $?
fi

# Cert-Manager
DEPLOY_CERT_MANAGER=$(yq eval '.DEPLOY_CERT_MANAGER' $CCCFG)
if test "$DEPLOY_CERT_MANAGER" = "true" -o "${DEPLOY_CERT_MANAGER:0:1}" = "v"; then
  apply_cert_manager.sh "$CLUSTER_NAME" || exit $?
fi

# Flux2
DEPLOY_FLUX=$(yq eval '.DEPLOY_FLUX' $CCCFG)
if test "$DEPLOY_FLUX" = "true"; then
  KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} flux install || exit $?
  touch ~/$CLUSTER_NAME/deployed-manifests.d/.flux
fi

# NGINX ingress
DEPLOY_NGINX_INGRESS=$(yq eval '.DEPLOY_NGINX_INGRESS' $CCCFG)
if test "$DEPLOY_NGINX_INGRESS" = "true" -o "${DEPLOY_NGINX_INGRESS:0:1}" = "v"; then
  apply_nginx_ingress.sh "$CLUSTER_NAME" || exit $?
fi

echo "# Wait for control plane of ${CLUSTER_NAME}"
kubectl config use-context kind-kind
kubectl wait --timeout=20m cluster "${CLUSTER_NAME}" --for=condition=Ready || exit 10
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
if test "$USE_CILIUM" = "true"; then
  KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} cilium status --wait
  echo "INFO: Use KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} cilium connectivity test for testing CNI"
fi
# Output some information on the cluster ...
kubectl $KCONTEXT get pods --all-namespaces
kubectl get openstackclusters
clusterctl describe cluster ${CLUSTER_NAME}
# Hints
echo "INFO: Use kubectl $KCONTEXT wait --for=condition=Ready --timeout=10m -n kube-system pods --all to wait for all cluster components to be ready"
echo "INFO: Pass $KCONTEXT parameter to kubectl or use KUBECONFIG=$KUBECONFIG_WORKLOADCLUSTER to control the workload cluster"
echo "SUCCESS: Cluster ${CLUSTER_NAME} deployed in $(($(date +%s)-$STARTTIME))s"
# eof
