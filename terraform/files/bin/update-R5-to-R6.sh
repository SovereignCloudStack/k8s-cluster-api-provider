#!/bin/bash
#
# This script updates cluster files clusterctl.yaml and cluster-template.yaml from R5 to R6 version of these files.
# To tweak cluster files of existing cluster use script as follows:
#    ```sh
#    ./update-R5-to-R6.sh <CLUSTER_NAME>
#    ```
# Alternatively, you can use `cluster-defaults` to change the cluster templates in `~/cluster-defaults/` which get used
# when creating new clusters as follows:
#    ```sh
#    ./update-R5-to-R6.sh cluster-defaults
#    ```
#
# Based on update-R4-to-R5.sh
# (c) Roman Hros <roman.hros@dnation.cloud>, 2/2024
# SPDX-License-Identifier: Apache-2.0

usage() {
  echo "Usage: update-R5-to-R6.sh <CLUSTER_NAME>"
  echo "Updates cluster files from R5 to R6 version."
  echo "To update cluster defaults for new clusters and install new dependencies"
  echo "use 'cluster-defaults' as <CLUSTER_NAME>."
  exit 1
}

restore() {
  echo "Updating failed ($1)" 1>&2
  cp -p clusterctl.yaml.backup clusterctl.yaml
  cp -p cluster-template.yaml.backup cluster-template.yaml
  kubectl --context kind-kind patch ValidatingWebhookConfiguration/capo-validating-webhook-configuration --type='json' -p='[{"op": "replace", "path": "/webhooks/0/rules/0/operations", "value":["CREATE", "UPDATE"]}]'
  exit "$1"
}

CLUSTER_NAME="$1"
if test -z "$CLUSTER_NAME"; then
  usage
else
  cd ~/"${CLUSTER_NAME}" || {
    echo "Cluster config $CLUSTER_NAME does not exist" 1>&2
    exit 2
  }
fi

# Backup files
echo "Backing up ~/${CLUSTER_NAME}/clusterctl.yaml and ~/${CLUSTER_NAME}/cluster-template.yaml"
echo "to ~/${CLUSTER_NAME}/clusterctl.yaml.backup and ~/${CLUSTER_NAME}/cluster-template.yaml.backup"
cp -p clusterctl.yaml clusterctl.yaml.backup
cp -p cluster-template.yaml cluster-template.yaml.backup

# General updates
if test ! -e /etc/profile.d/proxy.sh; then
  sudo touch /etc/profile.d/proxy.sh
fi

# Update clusterctl.yaml
if grep -q "PROXY_CMD\|OPENSTACK_CLUSTER_GEN" clusterctl.yaml || ! grep -q "OPENSTACK_CONTROL_PLANE_IP" clusterctl.yaml; then
  echo "Variables in clusterctl.yaml already updated"
else
  echo "Patching variables in clusterctl.yaml"
  # PR#705 Default to k8s v1.28
  sed -i 's/^KUBERNETES_VERSION: v1.27.5/KUBERNETES_VERSION: v1.28.7/' clusterctl.yaml || restore 1
  sed -i 's/^OPENSTACK_IMAGE_NAME: ubuntu-capi-image-v1.27.5/OPENSTACK_IMAGE_NAME: ubuntu-capi-image-v1.28.7/' clusterctl.yaml || restore 2
  # PR#693 Update dependency projectcalico/calico to v3.27.2
  sed -i 's/^CALICO_VERSION: v3.26.1/CALICO_VERSION: v3.27.2/' clusterctl.yaml || restore 3
  # PR#600 Add ClusterClass
  sed -i 's/^# Kubernetes version$/# Kubernetes version - only upgrades (+1 minor version) are allowed/' clusterctl.yaml || restore 4
  sed -i 'N;s/^# Increase generation counter when changing flavor or k8s version or other MD settings\nCONTROL_PLANE_MACHINE_GEN/# Increase generation counter when changing flavor or k8s version or other CP settings\nCONTROL_PLANE_MACHINE_GEN/' clusterctl.yaml || restore 5
  # PR#682 Remove unused OPENSTACK_CONTROL_PLANE_IP parameter
  sed -i '/^OPENSTACK_CONTROL_PLANE_IP: 127.0.0.1/d' clusterctl.yaml || restore 6
  sed -i 's/^# Use anti-affinity server groups (not working yet)/# Use anti-affinity server groups/' clusterctl.yaml || restore 7
  # PR#694 Do not alter clusterclass templates when there is no proxy setting
  sed -i '/^ETCD_UNSAFE_FS/a # configure_proxy.sh sets it to ". /etc/profile.d/proxy.sh; "\nPROXY_CMD: ""' clusterctl.yaml || restore 8
  # PR#718 Add generation counter for the OpenStackClusterTemplate
  sed -i '/^OPENSTACK_DNS_NAMESERVERS/a # Increase generation counter when changing restrict_kubeapi or other OC settings\nOPENSTACK_CLUSTER_GEN: geno01' clusterctl.yaml || restore 9

  # PR#584 Add option to specify external net via ID
  OPENSTACK_EXTERNAL_NETWORK=$(yq eval '.OPENSTACK_EXTERNAL_NETWORK_ID' clusterctl.yaml) || restore 10
  OPENSTACK_EXTERNAL_NETWORK_ID=$(openstack network show "$OPENSTACK_EXTERNAL_NETWORK" -f value -c id) || restore 11
  if test "$OPENSTACK_EXTERNAL_NETWORK" != "$OPENSTACK_EXTERNAL_NETWORK_ID"; then # Fix external_id
    sed -i "s/^OPENSTACK_EXTERNAL_NETWORK_ID: $OPENSTACK_EXTERNAL_NETWORK/OPENSTACK_EXTERNAL_NETWORK_ID: $OPENSTACK_EXTERNAL_NETWORK_ID/" clusterctl.yaml || restore 12
    if test "$CLUSTER_NAME" != "cluster-defaults"; then # Hack CAPO validation and fix spec.externalNetworkId of OpenStackCluster
      kubectl --context kind-kind patch ValidatingWebhookConfiguration/capo-validating-webhook-configuration --type='json' -p='[{"op": "replace", "path": "/webhooks/0/rules/0/operations", "value":["CREATE"]}]' || restore 13
      kubectl --context kind-kind patch OpenStackCluster/"$CLUSTER_NAME" --type='json' -p='[{"op": "replace", "path": "/spec/externalNetworkId", "value":"'"$OPENSTACK_EXTERNAL_NETWORK_ID"'"}]' || restore 14
      kubectl --context kind-kind patch ValidatingWebhookConfiguration/capo-validating-webhook-configuration --type='json' -p='[{"op": "replace", "path": "/webhooks/0/rules/0/operations", "value":["CREATE", "UPDATE"]}]' || restore 15
    fi
  fi
fi

# Nginx-ingress controller has been updated to version 1.9.6 in PR#704. This is a breaking change that includes updates
# of immutable fields. Therefore, if environment contains nginx ingress deployed via k8s-cluster-api-provider
# (variable DEPLOY_NGINX_INGRESS=true) the following k8s resources should be removed before R6 update (https://github.com/kubernetes/ingress-nginx/issues/5884):
if test "$CLUSTER_NAME" != "cluster-defaults"; then # Patch needed only when existing cluster is updated
  if grep -q "DEPLOY_NGINX_INGRESS: true" clusterctl.yaml; then
    KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
    kubectl "$KCONTEXT" delete job ingress-nginx-admission-create -n ingress-nginx
    kubectl "$KCONTEXT" delete job ingress-nginx-admission-patch -n ingress-nginx
  fi
fi

echo "Update of clusterctl.yaml file from R5 to R6 version has been successfully finished"

# Update cluster-template.yaml
if grep -q "topology\|PROXY_CMD\|provider-id" cluster-template.yaml; then
  echo "cluster-template.yaml already updated"
else
  echo "Patching cluster-template.yaml"
  echo "Warning: ~/${CLUSTER_NAME}/cluster-template.yaml will be replaced with R6 version ~/k8s-cluster-api-provider/terraform/files/template/cluster-template.yaml"
  echo "You can view the diff e.g. by git diff ~/${CLUSTER_NAME}/cluster-template.yaml ~/k8s-cluster-api-provider/terraform/files/template/cluster-template.yaml"
  echo "Or check the https://github.com/SovereignCloudStack/k8s-cluster-api-provider/compare/v6.0.0..v7.0.0#diff-9443b5beefb36721f409542f770a8bfa64eb458c75ee637b07e36639f6ec2424"
  if test "$CLUSTER_NAME" != "cluster-defaults"; then
    echo "Note: k8s resources in ~/${CLUSTER_NAME}/cluster-template.yaml are probably reordered so git diff can be different"
  fi
  echo "If you have not changed it manually, most likely it is safe to continue"
  read -p "Continue? (y/n) " -r
  if [[ ! $REPLY =~ ^[Yy] ]]; then
    exit 1
  fi
  cp ~/k8s-cluster-api-provider/terraform/files/template/cluster-template.yaml cluster-template.yaml || restore 16
fi

echo "Update of cluster-template.yaml file from R5 to R6 version has been successfully finished"
