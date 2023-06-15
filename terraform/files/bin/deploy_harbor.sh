#!/bin/bash
. ~/bin/cccfg.inc
export KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER}
export OS_CLOUD=$PREFIX-$CLUSTER_NAME

echo "Deploy harbor to $CLUSTER_NAME"

if test ! -s ~/kubernetes-manifests.d/harbor/base/harbor-secrets.bash; then
  curl -L https://raw.githubusercontent.com/SovereignCloudStack/k8s-harbor/main/base/harbor-secrets.bash -o ~/kubernetes-manifests.d/harbor/base/harbor-secrets.bash || exit 2
fi
sudo apt install -y pwgen apache2-utils

mkdir -p ~/$CLUSTER_NAME/deployed-manifests.d/harbor
cd ~/$CLUSTER_NAME/deployed-manifests.d/harbor
if test ! -s .ec2; then
  EC2CRED=$(openstack ec2 credentials create -f value -c access -c secret)
  read EC2CRED_ACCESS EC2CRED_SECRET < <(echo $EC2CRED)
  echo "#Created EC2Cred for the cluster $CLUSTER_NAME"
  cat > .ec2 <<EOT
REGISTRY_STORAGE_S3_ACCESSKEY="$EC2CRED_ACCESS"
REGISTRY_STORAGE_S3_SECRETKEY="$EC2CRED_SECRET"
EOT
fi

bash ~/kubernetes-manifests.d/harbor/base/harbor-secrets.bash
set -a
. ~/.harbor-settings
set +a
kubectl kustomize ~/kubernetes-manifests.d/harbor/envs/without-persistence | envsubst > harbor.yaml || exit 3
kubectl apply -f harbor.yaml || exit 9
