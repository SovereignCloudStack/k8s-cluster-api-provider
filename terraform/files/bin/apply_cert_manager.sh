#!/bin/bash
. ~/bin/cccfg.inc
export KUBECONFIG=~/.kube/config
. ~/$CLUSTER_NAME/harbor-settings

echo "Deploy cert-manager to $CLUSTER_NAME"
# cert-manager
DEPLOY_CERT_MANAGER=$($YQ '.DEPLOY_CERT_MANAGER' $CCCFG)
if test "$DEPLOY_CERT_MANAGER" = "false" -a "$DEPLOY_HARBOR" = "true" -a -n "$HARBOR_DOMAIN_NAME"; then
  DEPLOY_CERT_MANAGER="true"
fi
if test "$DEPLOY_CERT_MANAGER" = "true"; then
	CERTMGR_VERSION="v1.12.2"
elif test "$DEPLOY_CERT_MANAGER" = "false"; then
	echo "cert-manager disabled" 1>&2; exit 1
else
	CERTMGR_VERSION="$DEPLOY_CERT_MANAGER"
fi
# kubectl $KCONTEXT apply -f https://github.com/cert-manager/cert-manager/releases/download/v${CERTMGR_VERSION}/cert-manager.yaml
if test ! -s ~/kubernetes-manifests.d/cert-manager-${CERTMGR_VERSION}.yaml; then
	# FIXME: Check sig
	curl -L https://github.com/cert-manager/cert-manager/releases/download/${CERTMGR_VERSION}/cert-manager.yaml > ~/kubernetes-manifests.d/cert-manager-${CERTMGR_VERSION}.yaml || exit 2
fi
cp -p ~/kubernetes-manifests.d/cert-manager-${CERTMGR_VERSION}.yaml ~/${CLUSTER_NAME}/deployed-manifests.d/cert-manager.yaml
kubectl $KCONTEXT apply -f ~/${CLUSTER_NAME}/deployed-manifests.d/cert-manager.yaml || exit 9
# TODO: Optionally test, using cert-manager-test.yaml
# See https://cert-manager.io/docs/installation/kubernetes/
# kubectl plugin
#if ! test -x /usr/local/bin/kubectl-cert_manager; then
#	# FIXME: Check sig
#  	curl -L -o kubectl-cert-manager.tar.gz https://github.com/cert-manager/cert-manager/releases/download/v${CERTMGR_VERSION}/kubectl-cert_manager-linux-amd64.tar.gz
#	tar xzf kubectl-cert-manager.tar.gz && rm kubectl-cert-manager.tar.gz
#	sudo mv kubectl-cert_manager /usr/local/bin
#fi
# cmctl -- don't treat trouble as fatal error
if ! test -x /usr/local/bin/cmctl-$CERTMGR_VERSION; then
	cd ~
	OS=linux; ARCH=$(uname -m | sed 's/x86_64/amd64/')
	# FIXME: Check sig
	curl -L -o cmctl.tar.gz https://github.com/cert-manager/cert-manager/releases/download/${CERTMGR_VERSION}/cmctl-$OS-$ARCH.tar.gz
	tar xzf cmctl.tar.gz && rm cmctl.tar.gz
	sudo mv cmctl /usr/local/bin/cmctl-${CERTMGR_VERSION}
	sudo ln -sf cmctl-${CERTMGR_VERSION} /usr/local/bin/cmctl
	mv LICENS* ~/doc/LICENSE.cert-manager-${CERTMGR_VERSION}
fi
