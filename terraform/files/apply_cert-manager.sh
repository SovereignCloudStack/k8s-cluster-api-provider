#!/bin/bash
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=clusterctl.yaml; fi
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"

echo "Deploy cert-manager to $CLUSTER_NAME"
# cert-manager
#TODO: Make version configurable
CERTMGR_VERSION=1.7.0
# kubectl $KCONTEXT apply -f https://github.com/cert-manager/cert-manager/releases/download/v${CERTMGR_VERSION}/cert-manager.yaml
if test ! -s cert-manager.yaml; then
	# FIXME: Check sig
	curl -L https://github.com/cert-manager/cert-manager/releases/download/v${CERTMGR_VERSION}/cert-manager.yaml > cert-manager.yaml
fi
kubectl $KCONTEXT apply -f cert-manager.yaml || exit 9
# TODO: Optionally test, using cert-manager-test.yaml
# See https://cert-manager.io/docs/installation/kubernetes/
# kubectl plugin
#if ! test -x /usr/local/bin/kubectl-cert_manager; then
#	# FIXME: Check sig
#  	curl -L -o kubectl-cert-manager.tar.gz https://github.com/cert-manager/cert-manager/releases/download/v${CERTMGR_VERSION}/kubectl-cert_manager-linux-amd64.tar.gz
#	tar xzf kubectl-cert-manager.tar.gz && rm kubectl-cert-manager.tar.gz
#	sudo mv kubectl-cert_manager /usr/local/bin
#fi
# cmctl
if ! test -x /usr/local/bin/cmctl; then
	OS=linux; ARCH=$(uname -m | sed 's/x86_64/amd64/')
	# FIXME: Check sig
	curl -L -o cmctl.tar.gz https://github.com/cert-manager/cert-manager/releases/download/v${CERTMGR_VERSION}/cmctl-$OS-$ARCH.tar.gz
	tar xzf cmctl.tar.gz && rm cmctl.tar.gz
	sudo mv cmctl /usr/local/bin
fi
