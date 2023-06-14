#!/bin/bash
. ~/bin/cccfg.inc
export KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER}

echo "Deploy harbor to $CLUSTER_NAME"

if test ! -s ~/kubernetes-manifests.d/harbor/base/harbor-secrets.bash; then
  curl -L https://raw.githubusercontent.com/SovereignCloudStack/k8s-harbor/main/base/harbor-secrets.bash -o ~/kubernetes-manifests.d/harbor/base/harbor-secrets.bash || exit 2
fi
sudo apt install -y pwgen apache2-utils

cd ~/$CLUSTER_NAME/deployed-manifests.d
bash ~/kubernetes-manifests.d/harbor/base/harbor-secrets.bash
set -a
. ~/.harbor-settings
set +a
kubectl kustomize ~/kubernetes-manifests.d/harbor/envs/without-persistence | envsubst > harbor.yaml || exit 3
kubectl apply -f harbor.yaml || exit 9
