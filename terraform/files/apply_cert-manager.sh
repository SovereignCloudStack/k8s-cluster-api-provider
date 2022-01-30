#!/bin/bash
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=clusterctl.yaml; fi
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"

echo "Deploy cert-manager to $CLUSTER_NAME"
# cert-manager
# kubectl $KCONTEXT apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.1/cert-manager.yaml
if test ! -r cert-manager.yaml; then
	# FIXME: Check sig
	curl -L https://github.com/jetstack/cert-manager/releases/download/v1.1.1/cert-manager.yaml > cert-manager.yaml
fi
kubectl $KCONTEXT apply -f cert-manager.yaml || exit 9
# TODO: Optionally test, using cert-manager-test.yaml
# See https://cert-manager.io/v1.1-docs/installation/kubernetes/
# kubectl plugin
if ! test -x /usr/local/bin/kubectl-cert_manager; then
	# FIXME: Check sig
  	curl -L -o kubectl-cert-manager.tar.gz https://github.com/jetstack/cert-manager/releases/download/v1.1.1/kubectl-cert_manager-linux-amd64.tar.gz
	tar xzf kubectl-cert-manager.tar.gz && rm kubectl-cert-manager.tar.gz
	sudo mv kubectl-cert_manager /usr/local/bin
fi
