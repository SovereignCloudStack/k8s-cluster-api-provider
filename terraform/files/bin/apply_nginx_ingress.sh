#!/bin/bash
export KUBECONFIG=~/.kube/config
. ~/bin/cccfg.inc
. ~/$CLUSTER_NAME/harbor-settings
# Are we enabled? Has a version been set explicitly?
DEPLOY_NGINX_INGRESS=$(yq eval '.DEPLOY_NGINX_INGRESS' $CCCFG)
if test "$DEPLOY_NGINX_INGRESS" = "false" -a "$DEPLOY_HARBOR" = "true" -a -n "$HARBOR_DOMAIN_NAME"; then
  DEPLOY_NGINX_INGRESS="true"
fi
if test "$DEPLOY_NGINX_INGRESS" = "true"; then
	NGINX_VERSION="v1.8.1"
elif test "$DEPLOY_NGINX_INGRESS" = "false"; then
	echo "nginx ingress disabled" 1>&2; exit 1
else
	NGINX_VERSION="$DEPLOY_NGINX_INGRESS"
fi
NGINX_INGRESS_PROXY=$(yq eval '.NGINX_INGRESS_PROXY' $CCCFG)
NODE_CIDR=$(yq eval '.NODE_CIDR' $CCCFG)

cd ~/kubernetes-manifests.d/nginx-ingress
echo "Deploy NGINX ingress $NGINX_VERSION controller to $CLUSTER_NAME"
if test ! -s base/nginx-ingress-controller-${NGINX_VERSION}.yaml; then
	curl -L https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml > base/nginx-ingress-controller-${NGINX_VERSION}.yaml || exit 2
fi
# Default to original (may be overwritten by kustomize)
cp -p base/nginx-ingress-controller-${NGINX_VERSION}.yaml ~/$CLUSTER_NAME/deployed-manifests.d/nginx-ingress.yaml
ln -sf nginx-ingress-controller-${NGINX_VERSION}.yaml base/nginx-ingress-controller.yaml
if test "$NGINX_INGRESS_PROXY" = "false"; then
    if ! grep '^create\-monitor=true'  ~/$CLUSTER_NAME/cloud.conf >/dev/null 2>&1; then
	kustomize build nginx-monitor > ~/$CLUSTER_NAME/deployed-manifests.d/nginx-ingress.yaml || exit 3
    fi
else
    if ! grep '^lb\-provider=ovn' ~/$CLUSTER_NAME/cloud.conf >/dev/null 2>&1; then
	kustomize build nginx-proxy > ~/$CLUSTER_NAME/deployed-manifests.d/nginx-ingress.yaml || exit 3
    fi
fi
sed -i "s@set-real-ip-from: .*\$@set-real-ip-from: \"${NODE_CIDR}\"@" ~/$CLUSTER_NAME/deployed-manifests.d/nginx-ingress.yaml
sed -i "s@proxy-real-ip-cidr: .*\$@proxy-real-ip-cidr: \"${NODE_CIDR}\"@" ~/$CLUSTER_NAME/deployed-manifests.d/nginx-ingress.yaml
kubectl $KCONTEXT apply -f ~/$CLUSTER_NAME/deployed-manifests.d/nginx-ingress.yaml

