#!/usr/bin/env bash

##    desc: a helper for deploy a workload cluster on mgmt cluster
## license: Apache-2.0

STARTTIME=$(date +%s)
# variables
. ~/.capi-settings
. ~/bin/cccfg.inc

export PREFIX CLUSTER_NAME

# Ensure directory for cluster exists
if test ! -d ~/$CLUSTER_NAME; then
  mkdir -p ~/$CLUSTER_NAME
  cp -pr ~/cluster-defaults/* ~/$CLUSTER_NAME/
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
if test ! -d ~/$CLUSTER_NAME/containerd/; then
  # Ensure directory for containerd exists
  mkdir -p ~/cluster-defaults/containerd
  # Copy missing files individually as needed from containerd
  cp -pr ~/cluster-defaults/containerd/ ~/$CLUSTER_NAME/
fi
# Harbor settings
if test ! -s ~/$CLUSTER_NAME/harbor-settings; then
  # Ensure harbor-settings file exists
  if test ! -e ~/cluster-defaults/harbor-settings; then
    touch ~/cluster-defaults/harbor-settings
  fi
  cp -p ~/cluster-defaults/harbor-settings ~/$CLUSTER_NAME/
fi
. ~/$CLUSTER_NAME/harbor-settings

CCCFG="$HOME/${CLUSTER_NAME}/clusterctl.yaml"
fixup_k8s_version.sh $CCCFG || exit 1
~/bin/mng_cluster_ns.inc

# Add containerd registry host and cert files
configure_containerd.sh $CLUSTERAPI_TEMPLATE $CLUSTER_NAME || exit 1
# Handle wanted OVN loadbalancer
handle_ovn_lb.sh "$CLUSTER_NAME" || exit 1
# Determine whether we need a new application credential
create_appcred.sh || exit 1
# Update OS_CLOUD
#export OS_CLOUD=$PREFIX-$CLUSTER_NAME
export OS_CLOUD=$(yq eval '.OPENSTACK_CLOUD' $CCCFG)

#export OS_CLOUD=$(yq eval '.OPENSTACK_CLOUD' $CCCFG)
# Ensure image is there
wait_capi_image.sh "$1" || exit 1

# Switch to capi mgmt cluster
export KUBECONFIG=$HOME/.kube/config
~/bin/mng_cluster_ns.inc
# get the needed clusterapi-variables
echo "# show used variables for clustertemplate ${CLUSTERAPI_TEMPLATE}"

# TODO: Optional: Create own project for the cluster
# If so, we need to share the image with the new project

# TODO: Create pre-cluster app-creds:
# (1) For CAPO
# (2) For OCCM, CSI
#
# set OpenStack instance create timeout before the operator starts to create instances
CLUSTER_API_OPENSTACK_INSTANCE_CREATE_TIMEOUT=$(yq eval '.CLUSTER_API_OPENSTACK_INSTANCE_CREATE_TIMEOUT' $CCCFG)
kubectl -n capo-system set env deployment/capo-controller-manager CLUSTER_API_OPENSTACK_INSTANCE_CREATE_TIMEOUT=$CLUSTER_API_OPENSTACK_INSTANCE_CREATE_TIMEOUT

CONTROL_PLANE_MACHINE_COUNT=$(yq eval '.CONTROL_PLANE_MACHINE_COUNT' $CCCFG)
# Implement anti-affinity with server groups
if test "$CONTROL_PLANE_MACHINE_COUNT" -gt 0 && grep '^ *OPENSTACK_ANTI_AFFINITY: true' $CCCFG >/dev/null 2>&1; then
  SRVGRP=$(openstack server group list -f value)
  SRVGRP_CONTROLLER=$(echo "$SRVGRP" | grep "${PREFIX}-${CLUSTER_NAME}-controller" | sed 's/^\([0-9a-f\-]*\) .*$/\1/')
  SRVGRP_WORKER=$(echo "$SRVGRP" | grep "${PREFIX}-${CLUSTER_NAME}-worker" | sed 's/^\([0-9a-f\-]*\) .*$/\1/')
  if test -z "$SRVGRP_CONTROLLER"; then
    SRVGRP_CONTROLLER=$(openstack --os-compute-api-version 2.15 server group create --policy anti-affinity -f value -c id ${PREFIX}-${CLUSTER_NAME}-controller)
    SRVGRP_WORKER=$(openstack --os-compute-api-version 2.15 server group create --policy soft-anti-affinity -f value -c id ${PREFIX}-${CLUSTER_NAME}-worker)
  fi
  echo "Adding server groups $SRVGRP_CONTROLLER and $SRVGRP_WORKER to $CCCFG"
  if test -n "$SRVGRP_CONTROLLER"; then
    sed -i "s/^\(OPENSTACK_SRVGRP_CONTROLLER:\).*\$/\1 $SRVGRP_CONTROLLER/" "$CCCFG"
  else
    echo "ERROR: Server group could not be created" 1>&2
    # exit 2
    sed -i "s/^\(OPENSTACK_SRVGRP_CONTROLLER:\).*\$/\1 nonono/" "$CCCFG"
  fi
  if test -n "$SRVGRP_WORKER"; then
    sed -i "s/^\(OPENSTACK_SRVGRP_WORKER:\).*\$/\1 $SRVGRP_WORKER/" "$CCCFG"
  else
    sed -i "s/^\(OPENSTACK_SRVGRP_WORKER:\).*\$/\1 nonono/" "$CCCFG"
  fi
fi

# Check that the flavors exist and allocate volumes if needed
fixup_flavor_volumes.sh "$CCCFG" "${CLUSTERAPI_TEMPLATE}" || exit 2

cp -p "$CCCFG" $HOME/.cluster-api/clusterctl.yaml
KCCCFG="--config $CCCFG"
#clusterctl $KCCCFG config cluster ${CLUSTER_NAME} --list-variables --from ${CLUSTERAPI_TEMPLATE}
clusterctl $KCCCFG generate cluster "${CLUSTER_NAME}" --list-variables --from ${CLUSTERAPI_TEMPLATE} || exit 2

# the needed variables are read from $HOME/.cluster-api/clusterctl.yaml
echo "# rendering clusterconfig from template"
unset CLUSTER_EXISTS
if test -e ~/${CLUSTER_NAME}/${CLUSTER_NAME}-config.yaml; then
  echo " Overwriting config for ${CLUSTER_NAME}"
  CLUSTERS=$(kubectl get cluster --all-namespaces -o jsonpath='{range .items[?(@.metadata.name == "'$CLUSTER_NAME'")]}{.metadata.name}{end}')
  if test -n "$CLUSTERS"; then
    export CLUSTER_EXISTS=1
    echo -e " Warning: Cluster exists\n Hit ^C to interrupt"
    sleep 6
  fi
fi
#clusterctl $KCCCFG config cluster ${CLUSTER_NAME} --from ${CLUSTERAPI_TEMPLATE} > rendered-${CLUSTERAPI_TEMPLATE}
clusterctl $KCCCFG generate cluster "${CLUSTER_NAME}" --from ${CLUSTERAPI_TEMPLATE} >~/${CLUSTER_NAME}/${CLUSTER_NAME}-config.yaml
# Remove empty serverGroupID
sed -i '/^ *serverGroupID: nonono$/d' ~/${CLUSTER_NAME}/${CLUSTER_NAME}-config.yaml

# Apply kubeapi access restrictions
apply_kubeapi_cidrs.sh "$CCCFG" ~/${CLUSTER_NAME}/${CLUSTER_NAME}-config.yaml

# Test for CILIUM
USE_CILIUM=$(yq eval '.USE_CILIUM' $CCCFG)
if test "$USE_CILIUM" = "true" -o "${USE_CILIUM:0:1}" = "v"; then
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
sync
sleep 2
#wget https://gx-scs.okeanos.dev --quiet -O /dev/null
#ping -c1 -w2 9.9.9.9 >/dev/null 2>&1
if test "$CLUSTER_EXISTS" != "1"; then sleep 12; fi
kubectl wait --timeout=5s --for=condition=certificatesavailable kubeadmcontrolplanes -l cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} >/dev/null 2>&1 || sleep 25
kubectl wait --timeout=14m --for=condition=certificatesavailable kubeadmcontrolplanes -l cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} || exit 1
kubectl wait --timeout=8m --for=condition=Ready machine -l cluster.x-k8s.io/control-plane,cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} || exit 4

kubectl get secrets "${CLUSTER_NAME}-kubeconfig" --output go-template='{{ .data.value | base64decode }}' >"${KUBECONFIG_WORKLOADCLUSTER}" || exit 5
chmod 0600 "${KUBECONFIG_WORKLOADCLUSTER}"
echo "INFO: kubeconfig for ${CLUSTER_NAME} in ${KUBECONFIG_WORKLOADCLUSTER}"
export KUBECONFIG="$HOME/.kube/config:${KUBECONFIG_WORKLOADCLUSTER}"
MERGED=$(mktemp merged.yaml.XXXXXX)
kubectl config view --flatten >$MERGED
mv $MERGED $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"

SLEEP=0
until kubectl $KCONTEXT api-resources; do
  echo "[$SLEEP] waiting for api-server"
  sleep 10
  let SLEEP+=10
done

# CNI
SLEEP=0
until kubectl $KCONTEXT -n kube-system get daemonset/kube-proxy -o=jsonpath='{.metadata.name}' >/dev/null 2>&1; do
  echo "[$SLEEP] waiting for kube-proxy"
  sleep 10
  let SLEEP+=10
done

echo "waiting for kube-proxy to become ready"
kubectl $KCONTEXT -n kube-system wait --for=condition=ready --timeout=5m pods -l k8s-app=kube-proxy

echo "# Deploy services (CNI, OCCM, CSI, Metrics, Cert-Manager, Flux2, Ingress)"
MTU_VALUE=$(yq eval '.MTU_VALUE' $CCCFG)
if test "$USE_CILIUM" = "true" -o "${USE_CILIUM:0:1}" = "v"; then
  DEPLOY_GATEWAY_API=$(yq eval '.DEPLOY_GATEWAY_API == true' $CCCFG)
  if test "${DEPLOY_GATEWAY_API}" = "true"; then
    KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
    KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
    KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
    KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
    KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
  fi
  # FIXME: Do we need to allow overriding MTU here as well?
  CILIUM_VERSION="v1.14.0"
  if test "${USE_CILIUM:0:1}" = "v"; then
    CILIUM_VERSION="${USE_CILIUM}"
  fi
  POD_CIDR=$(yq eval '.POD_CIDR' $CCCFG)
  KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} cilium install --version $CILIUM_VERSION \
    --helm-set-string "ipam.operator.clusterPoolIPv4PodCIDRList={${POD_CIDR}}" \
    --helm-set kubeProxyReplacement=${DEPLOY_GATEWAY_API} \
    --helm-set gatewayAPI.enabled=${DEPLOY_GATEWAY_API} \
    --helm-set cni.chainingMode=portmap \
    --helm-set sessionAffinity=true
  touch ~/$CLUSTER_NAME/deployed-manifests.d/.cilium
else
  CALICO_VERSION=$(yq eval '.CALICO_VERSION' $CCCFG)
  if test ! -s ~/kubernetes-manifests.d/calico-${CALICO_VERSION}.yaml; then
    curl -L https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/calico.yaml -o ~/kubernetes-manifests.d/calico-${CALICO_VERSION}.yaml
  fi
  sed "s/\(veth_mtu.\).*/\1 \"${MTU_VALUE}\"/g" ~/kubernetes-manifests.d/calico-${CALICO_VERSION}.yaml >~/$CLUSTER_NAME/deployed-manifests.d/calico.yaml
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
if test "$DEPLOY_CERT_MANAGER" = "false" -a "$DEPLOY_HARBOR" = "true" -a -n "$HARBOR_DOMAIN_NAME"; then
  echo "INFO: Installation of cert-manager forced by Harbor deployment"
  DEPLOY_CERT_MANAGER="true"
fi
if test "$DEPLOY_CERT_MANAGER" = "true" -o "${DEPLOY_CERT_MANAGER:0:1}" = "v"; then
  apply_cert_manager.sh "$CLUSTER_NAME" || exit $?
fi

# Flux2
DEPLOY_FLUX=$(yq eval '.DEPLOY_FLUX' $CCCFG)
if test "$DEPLOY_FLUX" = "false" -a "$DEPLOY_HARBOR" = "true"; then
  echo "INFO: Installation of flux forced by Harbor deployment"
  DEPLOY_FLUX="true"
fi
if test "$DEPLOY_FLUX" = "true" -o "${DEPLOY_FLUX:0:1}" = "v"; then
  FLUX_INSTALL_OPTS="--timeout 10m0s"
  if test "${DEPLOY_FLUX:0:1}" = "v"; then
    FLUX_INSTALL_OPTS+=" --version $DEPLOY_FLUX"
  fi
  echo "Deploy flux to $CLUSTER_NAME"
  KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} flux install $FLUX_INSTALL_OPTS || exit $?
  touch ~/$CLUSTER_NAME/deployed-manifests.d/.flux
fi

# NGINX ingress
DEPLOY_NGINX_INGRESS=$(yq eval '.DEPLOY_NGINX_INGRESS' $CCCFG)
if test "$DEPLOY_NGINX_INGRESS" = "false" -a "$DEPLOY_HARBOR" = "true" -a -n "$HARBOR_DOMAIN_NAME"; then
  echo "INFO: Installation of ingress-nginx forced by Harbor deployment"
  DEPLOY_NGINX_INGRESS="true"
fi
if test "$DEPLOY_NGINX_INGRESS" = "true" -o "${DEPLOY_NGINX_INGRESS:0:1}" = "v"; then
  apply_nginx_ingress.sh "$CLUSTER_NAME" || exit $?
fi

echo "# Wait for control plane of ${CLUSTER_NAME}"
~/bin/mng_cluster_ns.inc
kubectl wait --timeout=20m cluster "${CLUSTER_NAME}" --for=condition=Ready || exit 10
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
if test "$USE_CILIUM" = "true" -o "${USE_CILIUM:0:1}" = "v"; then
  KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} cilium status --wait
  echo "INFO: Use KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER} cilium connectivity test for testing CNI"
fi

# Harbor
if test "$DEPLOY_HARBOR" = "true"; then
  deploy_harbor.sh "$CLUSTER_NAME" || exit $?
  echo "SUCCESS: Harbor deployed in cluster ${CLUSTER_NAME}"
  echo "INFO: For admin password use kubectl $KCONTEXT get secret harbor-secrets -o jsonpath='{.data.values\.yaml}' | base64 -d | yq .harborAdminPassword"
  echo "INFO: You can access it via k8s service 'harbor', e.g. http://harbor."
  echo "INFO: If you deployed Harbor with domain name and ingress"
  echo "INFO: use kubectl $KCONTEXT -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress}'"
  echo "INFO: , take LoadBalancer IP address and create DNS record for Harbor so certificate can be issued."
  echo "INFO: Then you can access it at https://${HARBOR_DOMAIN_NAME:-domain_name}"
fi

# Output some information on the cluster ...
kubectl $KCONTEXT get pods --all-namespaces
kubectl get openstackclusters
clusterctl $KCCCFG describe cluster ${CLUSTER_NAME} --grouping=false
# Hints
echo "INFO: Use kubectl $KCONTEXT wait --for=condition=Ready --timeout=10m -n kube-system pods --all to wait for all cluster components to be ready"
echo "INFO: Pass $KCONTEXT parameter to kubectl or use KUBECONFIG=$KUBECONFIG_WORKLOADCLUSTER to control the workload cluster"
echo "SUCCESS: Cluster ${CLUSTER_NAME} deployed in $(($(date +%s) - $STARTTIME))s"
# eof
