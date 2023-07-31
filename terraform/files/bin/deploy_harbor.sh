#!/bin/bash
. ~/bin/cccfg.inc
export KUBECONFIG=${KUBECONFIG_WORKLOADCLUSTER}
export OS_CLOUD=$PREFIX-$CLUSTER_NAME

# export harbor variables as env for envsubst
set -a
. ~/$CLUSTER_NAME/harbor-settings
set +a

echo "Deploy harbor to $CLUSTER_NAME"

mkdir -p ~/$CLUSTER_NAME/deployed-manifests.d/harbor
cd ~/$CLUSTER_NAME/deployed-manifests.d/harbor

# download scripts
if test ! -s ~/kubernetes-manifests.d/harbor/harbor-secrets.bash; then
  curl -L https://raw.githubusercontent.com/SovereignCloudStack/k8s-harbor/main/base/harbor-secrets.bash -o ~/kubernetes-manifests.d/harbor/harbor-secrets.bash || exit 2
fi
if test ! -s ~/kubernetes-manifests.d/harbor/s3-credentials.bash; then
  curl -L https://raw.githubusercontent.com/SovereignCloudStack/k8s-harbor/main/envs/public/s3-credentials.bash -o ~/kubernetes-manifests.d/harbor/s3-credentials.bash || exit 2
fi
sudo apt install -y pwgen apache2-utils

# generate harbor secrets
bash ~/kubernetes-manifests.d/harbor/harbor-secrets.bash

# create ec2 credentials if they don't already exist
if test ! -s .ec2; then
  EC2CRED=$(openstack ec2 credentials create -f value -c access -c secret)
  read EC2CRED_ACCESS EC2CRED_SECRET < <(echo $EC2CRED)
  echo "#Created EC2Cred for the cluster $CLUSTER_NAME"
  cat > .ec2 <<EOT
REGISTRY_STORAGE_S3_ACCESSKEY=$EC2CRED_ACCESS
REGISTRY_STORAGE_S3_SECRETKEY=$EC2CRED_SECRET
EOT
fi

# create s3 secret
. .ec2
bash ~/kubernetes-manifests.d/harbor/s3-credentials.bash "$REGISTRY_STORAGE_S3_ACCESSKEY" "$REGISTRY_STORAGE_S3_SECRETKEY"

# create/update bucket, should be idempotent
BUCKET_NAME=$PREFIX-$CLUSTER_NAME-harbor-registry
echo "Creating/updating bucket $BUCKET_NAME"
openstack container create "$BUCKET_NAME"

# get s3 regionendpoint, bucket and region
SWIFT_URL=$(openstack catalog show object-store -f yaml | yq eval '.endpoints.[] | select(.interface == "public") | .url')
SWIFT_URL_SHORT=$(echo "$SWIFT_URL" | sed s'/https:\/\///' | sed s'/\/.*$//')
REGION=$(print-cloud.py | yq eval ".clouds.${OS_CLOUD}.region_name")

export HARBOR_S3_BUCKET=$BUCKET_NAME
export HARBOR_S3_ENDPOINT=https://$SWIFT_URL_SHORT
export HARBOR_S3_REGION=$REGION

# deploy harbor
if test -n "$HARBOR_DOMAIN_NAME"; then
  kubectl kustomize ~/kubernetes-manifests.d/harbor/envs/ingress | envsubst > harbor.yaml
else
  kubectl kustomize ~/kubernetes-manifests.d/harbor/envs/clusterIP | envsubst > harbor.yaml
fi
kubectl apply -f harbor.yaml
