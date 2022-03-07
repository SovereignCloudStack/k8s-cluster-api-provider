#!/bin/bash
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e ~/clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=~/clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=~/clusterctl.yaml; fi
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"

echo "Deploy NGINX ingress controller to $CLUSTER_NAME"
if test ! -s ~/kubernetes-manifests.d/nginx-ingress-controller.yaml; then
	curl -L https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.1/deploy/static/provider/cloud/deploy.yaml > ~/kubernetes-manifests.d/nginx-ingress-controller.yaml
fi
kubectl $KCONTEXT apply -f ~/kubernetes-manifests.d/nginx-ingress-controller.yaml

