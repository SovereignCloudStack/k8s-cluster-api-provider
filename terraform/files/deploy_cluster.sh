#!/usr/bin/env bash

##    desc: a helper for deploy a workload cluster on mgmt cluster
## license: Apache-2.0

# variables
CLUSTERAPI_TEMPLATE=cluster-template.yaml
CLUSTER_NAME=testcluster
if test -n "$1"; then CLUSTER_NAME="$1"; fi
KUBECONFIG_WORKLOADCLUSTER="${CLUSTER_NAME}.yaml"

# Switch to capi mgmt cluster
kubectl config use-context kind-kind
# get the needed clusterapi-variables
echo "# show used variables for clustertemplate ${CLUSTERAPI_TEMPLATE}"
if test -e "$HOME/clusterctl-${CLUSTER_NAME}.yaml"; then
	cp -p "$HOME/clusterctl-${CLUSTER_NAME}.yaml" $HOME/.cluster-api/clusterctl.yaml
else
	cp -p $HOME/clusterctl.yaml $HOME/.cluster-api/clusterctl.yaml
fi
#clusterctl config cluster ${CLUSTER_NAME} --list-variables --from ${CLUSTERAPI_TEMPLATE}
clusterctl generate cluster "${CLUSTER_NAME}" --list-variables --from ${CLUSTERAPI_TEMPLATE}

# the need variables are set to $HOME/.cluster-api/clusterctl.yaml
echo "# rendering clusterconfig from template"
if test -e "${CLUSTER_NAME}-config.yaml"; then
	echo "Warning: Overwriting config for ${CLUSTER_NAME}"
	echo "Hit ^C to interrupt"
	sleep 3
fi
#clusterctl config cluster ${CLUSTER_NAME} --from ${CLUSTERAPI_TEMPLATE} > rendered-${CLUSTERAPI_TEMPLATE}
clusterctl generate cluster "${CLUSTER_NAME}" --from ${CLUSTERAPI_TEMPLATE} > "${CLUSTER_NAME}-config.yaml"

# apply to the kubernetes mgmt cluster
echo "# apply configuration and deploy cluster ${CLUSTER_NAME}"
kubectl apply -f "${CLUSTER_NAME}-config.yaml"

#Waiting for Clusterstate Ready
echo "Waiting for Cluster=Ready"
#wget https://gx-scs.okeanos.dev --quiet -O /dev/null
ping -c1 -w2 9.9.9.9 >/dev/null 2>&1
sleep 20
kubectl wait --timeout=10m --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}
kubectl wait --timeout=5m --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}
kubectl wait --timeout=5m --for=condition=Ready machine -l cluster.x-k8s.io/control-plane

kubectl get secrets "${CLUSTER_NAME}-kubeconfig" --output go-template='{{ .data.value | base64decode }}' > "${KUBECONFIG_WORKLOADCLUSTER}"
echo "kubeconfig for ${CLUSTER_NAME} in ${KUBECONFIG_WORKLOADCLUSTER}"
export KUBECONFIG=".kube/config:${KUBECONFIG_WORKLOADCLUSTER}"
MERGED=$(mktemp merged.yaml.XXXXXX)
kubectl config view --flatten > $MERGED
mv $MERGED .kube/config
export KUBECONFIG=.kube/config
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"

SLEEP=0
until kubectl $KCONTEXT api-resources
do
    echo "[$SLEEP] waiting for api-server"
    sleep 10
    SLEEP=$(( SLEEP + 10 ))
done

# Tweak calico MTU
# MTU=`yq eval '.MTU_VALUE' clusterctl.yaml`
# kubectl patch configmap/calico-config -n kube-system --type merge -p '{"data":{"veth_mtu": "'${MTU}'"}}'
# kubectl rollout restart daemonset calico-node -n kube-system

# create cloud.conf secret
echo "Install external OpenStack cloud provider"
kubectl $KCONTEXT create secret generic cloud-config --from-file="$HOME"/cloud.conf -n kube-system
# install external cloud-provider openstack
kubectl $KCONTEXT apply -f ~/openstack.yaml

# apply cinder-csi
kubectl $KCONTEXT apply -f ~/cinder.yaml

# Metrics server
# kubectl $KCONTEXT apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "Wait for control plane of ${CLUSTER_NAME}"
kubectl config use-context kind-kind
kubectl wait --timeout=20m cluster "${CLUSTER_NAME}" --for=condition=Ready
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
kubectl get openstackclusters
# Hints
echo "Use kubectl $KCONTEXT apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml to deploy the metrics service"
echo "Use kubectl $KCONTEXT wait --for=condition=Ready --timeout=10m -n kube-system pods --all to wait for all cluster components to be ready"
echo "Use $KCONTEXT parameter to kubectl to control the workload cluster"
# eof
