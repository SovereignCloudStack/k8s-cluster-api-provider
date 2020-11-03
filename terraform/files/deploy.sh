#!/usr/bin/env bash

##    desc: a helper for deploy a workload cluster on mgmt cluster
## license: Apache-2.0

# variables
CLUSTERAPI_VERSION=0.3.1
CLUSTERAPI_TEMPLATE=cluster-template.yaml
CLUSTER_NAME=capi

# get the clusterctl version
clusterctl version --output yaml

# cp clusterctl.yaml to the right place
cp $HOME/clusterctl.yaml $HOME/.cluster-api/clusterctl.yaml

# deploy cluster-api on mgmt cluster
clusterctl init --infrastructure openstack:v${CLUSTERAPI_VERSION}

# wait for CAPI pods
kubectl wait --for=condition=Ready --timeout=5m -n capi-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capi-webhook-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capi-kubeadm-bootstrap-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capi-kubeadm-control-plane-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capo-system pod --all

# wait for CAPO crds
kubectl wait --for condition=established --timeout=60s crds/openstackmachines.infrastructure.cluster.x-k8s.io
kubectl wait --for condition=established --timeout=60s crds/openstackmachinetemplates.infrastructure.cluster.x-k8s.io
kubectl wait --for condition=established --timeout=60s crds/openstackclusters.infrastructure.cluster.x-k8s.io

# get the cluster-template for cluster
curl -OL https://github.com/kubernetes-sigs/cluster-api-provider-openstack/releases/download/v${CLUSTERAPI_VERSION}/${CLUSTERAPI_TEMPLATE}

# get the needed clusterapi-variables
clusterctl config cluster ${CLUSTER_NAME} --list-variables --from ${CLUSTERAPI_TEMPLATE}

# the need variables are set to $HOME/.cluster-api/clusterctl.yaml
clusterctl config cluster ${CLUSTER_NAME} --from ${CLUSTERAPI_TEMPLATE} > rendered-${CLUSTERAPI_TEMPLATE}

# apply to the kubernetes mgmt cluster
kubectl apply -f rendered-${CLUSTERAPI_TEMPLATE}

# eof
