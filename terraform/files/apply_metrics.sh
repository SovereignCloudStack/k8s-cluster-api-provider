#!/bin/bash
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=clusterctl.yaml; fi
#NAMESPACE=$(yq eval .NAMESPACE $CCCFG)
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}" # "--namespace=$NAMESPACE"

echo "Deploy metrics server to $CLUSTER_NAME"
# Metrics server
# kubectl $KCONTEXT create -f https://raw.githubusercontent.com/pythianarora/total-practice/master/sample-kubernetes-code/metrics-server.yaml
# kubectl $KCONTEXT apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
if test ! -r metrics-server.yaml; then
	curl -L https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | sed '/        - --kubelet-use-node-status-port/a\        - --kubelet-insecure-tls' > metrics-server.yaml
fi
kubectl $KCONTEXT apply -f metrics-server.yaml || exit 9

