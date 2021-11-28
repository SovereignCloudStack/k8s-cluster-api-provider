#!/usr/bin/env bash

##    desc: a helper for deploy a workload cluster on mgmt cluster
## license: Apache-2.0

STARTTIME=$(date +%s)
# variables
CLUSTERAPI_TEMPLATE=cluster-template.yaml
CLUSTER_NAME=testcluster
if test -n "$1"; then CLUSTER_NAME="$1"; fi
KUBECONFIG_WORKLOADCLUSTER="${CLUSTER_NAME}.yaml"

# Switch to capi mgmt cluster
export KUBECONFIG=~/.kube/config
kubectl config use-context kind-kind || exit 1
# get the needed clusterapi-variables
echo "# show used variables for clustertemplate ${CLUSTERAPI_TEMPLATE}"
if test -e "$HOME/clusterctl-${CLUSTER_NAME}.yaml"; then
	CCCFG="$HOME/clusterctl-${CLUSTER_NAME}.yaml"
else
	CCCFG=$HOME/clusterctl.yaml
fi
cp -p "$CCCFG" $HOME/.cluster-api/clusterctl.yaml

#clusterctl config cluster ${CLUSTER_NAME} --list-variables --from ${CLUSTERAPI_TEMPLATE}
clusterctl generate cluster "${CLUSTER_NAME}" --list-variables --from ${CLUSTERAPI_TEMPLATE} || exit 2

# the needed variables are read from $HOME/.cluster-api/clusterctl.yaml
echo "# rendering clusterconfig from template"
if test -e "${CLUSTER_NAME}-config.yaml"; then
	echo "Warning: Overwriting config for ${CLUSTER_NAME}"
	echo "Hit ^C to interrupt"
	sleep 5
	nowait=1
fi
#clusterctl config cluster ${CLUSTER_NAME} --from ${CLUSTERAPI_TEMPLATE} > rendered-${CLUSTERAPI_TEMPLATE}
clusterctl generate cluster "${CLUSTER_NAME}" --from ${CLUSTERAPI_TEMPLATE} > "${CLUSTER_NAME}-config.yaml"

# apply to the kubernetes mgmt cluster
echo "# apply configuration and deploy cluster ${CLUSTER_NAME}"
kubectl apply -f "${CLUSTER_NAME}-config.yaml" || exit 3

#Waiting for Clusterstate Ready
echo "Waiting for Cluster=Ready"
#wget https://gx-scs.okeanos.dev --quiet -O /dev/null
ping -c1 -w2 9.9.9.9 >/dev/null 2>&1
if test "$nowait" != "1"; then sleep 20; fi
kubectl wait --timeout=10m --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} || exit 1
kubectl wait --timeout=5m --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} || exit 1
kubectl wait --timeout=5m --for=condition=Ready machine -l cluster.x-k8s.io/control-plane || exit 4

kubectl get secrets "${CLUSTER_NAME}-kubeconfig" --output go-template='{{ .data.value | base64decode }}' > "${KUBECONFIG_WORKLOADCLUSTER}" || exit 5
chmod og-rw "${KUBECONFIG_WORKLOADCLUSTER}"
echo "kubeconfig for ${CLUSTER_NAME} in ${KUBECONFIG_WORKLOADCLUSTER}"
export KUBECONFIG=".kube/config:${KUBECONFIG_WORKLOADCLUSTER}"
MERGED=$(mktemp merged.yaml.XXXXXX)
kubectl config view --flatten > $MERGED
mv $MERGED .kube/config
export KUBECONFIG=.kube/config
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
#NAMESPACE=$(yq eval .NAMESPACE $CCCFG)
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}" # "--namespace=$NAMESPACE"

SLEEP=0
until kubectl $KCONTEXT api-resources
do
    echo "[$SLEEP] waiting for api-server"
    sleep 10
    let SLEEP+=10
done

# Metrics
DEPLOY_METRICS=$(yq eval '.DEPLOY_METRICS' $CCCFG)
if test "$DEPLOY_METRICS" = "true"; then
  bash ./apply_metrics.sh "$CLUSTER_NAME" || exit $?
fi

# OpenStack, Cinder
bash ./apply_openstack_integration.sh "$CLUSTER_NAME" || exit $?
bash ./apply_cindercsi.sh "$CLUSTER_NAME" || exit $?

# NGINX ingress
DEPLOY_NGINX_INGRESS=$(yq eval '.DEPLOY_NGINX_INGRESS' $CCCFG)
if test "$DEPLOY_NGINX_INGRESS" = "true"; then
  bash ./apply_nginx_ingress.sh "$CLUSTER_NAME" || exit $?
fi
echo "Wait for control plane of ${CLUSTER_NAME}"
kubectl config use-context kind-kind
kubectl wait --timeout=20m cluster "${CLUSTER_NAME}" --for=condition=Ready || exit 10
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
kubectl $KCONTEXT get pods --all-namespaces
kubectl get openstackclusters
clusterctl describe cluster ${CLUSTER_NAME}
# Hints
echo "Cluster ${CLUSTER_NAME} deployed in $(($(date +%s)-$STARTTIME))s"
if test "$DEPLOY_METRICS" != "true"; then
    echo "Use curl -L https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | sed '/        - --kubelet-use-node-status-port/a\\        - --kubelet-insecure-tls' | kubectl $KCONTEXT apply -f -  to deploy the metrics service"
fi
echo "Use kubectl $KCONTEXT wait --for=condition=Ready --timeout=10m -n kube-system pods --all to wait for all cluster components to be ready"
echo "Pass $KCONTEXT parameter to kubectl or use KUBECONFIG=$KUBECONFIG_WORKLOADCLUSTER to control the workload cluster"
# eof
