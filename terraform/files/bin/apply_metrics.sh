#!/bin/bash
export KUBECONFIG=~/.kube/config
. ~/bin/cccfg.inc

echo "Deploy metrics server to $CLUSTER_NAME"
# Metrics server
# kubectl $KCONTEXT create -f https://raw.githubusercontent.com/pythianarora/total-practice/master/sample-kubernetes-code/metrics-server.yaml
# kubectl $KCONTEXT apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
if test ! -s ~/kubernetes-manifests.d/metrics-server.yaml; then
	curl -L https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | sed '/        - --kubelet-use-node-status-port/a\        - --kubelet-insecure-tls' > ~/kubernetes-manifests.d/metrics-server.yaml
fi
cp -p ~/kubernetes-manifests.d/metrics-server.yaml ~/${CLUSTER_NAME}/
kubectl $KCONTEXT apply -f ~/${CLUSTER_NAME}/metrics-server.yaml || exit 9

