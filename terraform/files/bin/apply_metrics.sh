#!/bin/bash
export KUBECONFIG=~/.kube/config

# imports
. ~/bin/utils.inc
. ~/bin/cccfg.inc

# Switch to capi workload cluster
if [ -z ${KCONTEXT} ]; then
  setup_kubectl_context_workspace
  set_workload_cluster_kubectl_namespace
fi

METRICS_VERSION=v0.6.4

echo "Deploy metrics server to $CLUSTER_NAME"
# Metrics server
if test ! -s ~/kubernetes-manifests.d/metrics-server-${METRICS_VERSION}.yaml; then
	curl -L https://github.com/kubernetes-sigs/metrics-server/releases/download/$METRICS_VERSION/components.yaml | sed '/        - --kubelet-use-node-status-port/a\        - --kubelet-insecure-tls' > ~/kubernetes-manifests.d/metrics-server-${METRICS_VERSION}.yaml
fi
cp -p ~/kubernetes-manifests.d/metrics-server-${METRICS_VERSION}.yaml ~/${CLUSTER_NAME}/deployed-manifests.d/metrics-server.yaml
kubectl --context=$KCONTEXT apply -f ~/${CLUSTER_NAME}/deployed-manifests.d/metrics-server.yaml || exit 9
