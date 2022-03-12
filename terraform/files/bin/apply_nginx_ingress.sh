#!/bin/bash
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e ~/clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=~/clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=~/clusterctl.yaml; fi
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
# Are we enabled? Has a version been set explicitly?
DEPLOY_NGINX_INGRESS=$(yq eval '.DEPLOY_NGINX_INGRESS' $CCCFG)
if test "$DEPLOY_NGINX_INGRESS" = "true"; then
	NGINX_VERSION="v1.1.2"
elif test "$DEPLOY_NGINX_INGRESS" = "false"; then
	echo "nginx ingress disabled" 1>&2; exit 1
else
	NGINX_VERSION="$DEPLOY_NGINX_INGRESS"
fi

echo "Deploy NGINX ingress $NGINX_VERSION controller to $CLUSTER_NAME"
if test ! -s ~/kubernetes-manifests.d/nginx-ingress-controller-${NGINX_VERSION}.yaml; then
	curl -L https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml > ~/kubernetes-manifests.d/nginx-ingress-controller-${NGINX_VERSION}.yaml
fi
kubectl $KCONTEXT apply -f ~/kubernetes-manifests.d/nginx-ingress-controller-${NGINX_VERSION}.yaml

