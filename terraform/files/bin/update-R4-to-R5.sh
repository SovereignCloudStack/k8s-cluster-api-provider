#!/bin/bash
# !This script is under development and will be stabilized within the release R5!
#
# This script updates cluster files cluster-template.yaml and clusterctl.yaml from R4 to R5 version of these files.
# To tweak cluster files of existing cluster use script as follows:
#    ```sh
#    ./update-R4-to-R5.sh <CLUSTER_NAME>
#    ```
# Alternatively, you can use `cluster-defaults` to change the cluster templates in `~/cluster-defaults/` which get used
# when creating new clusters as follows:
#    ```sh
#    ./update-R4-to-R5.sh cluster-defaults
#    ```
#
# (c) Matej Feder <feder.mato@gmail.com>, 7/2023
# SPDX-License-Identifier: Apache-2.0

usage() {
  echo "!This script is under development and will be stabilized within the release R5!"
  echo "Usage: update-R4-to-R5.sh <CLUSTER_NAME>"
  echo "Updates cluster files from R4 to R5 version."
  echo "To update cluster defaults for new clusters and install new dependencies"
  echo "use 'cluster-defaults' as <CLUSTER_NAME>."
  exit 1
}

restore() {
  echo "Updating failed ($1)" 1>&2
  cp -p cluster-template.yaml.backup cluster-template.yaml
  cp -p clusterctl.yaml.backup clusterctl.yaml
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
cp -p cluster-template.yaml cluster-template.yaml.backup
cp -p clusterctl.yaml clusterctl.yaml.backup

# Update cluster-template.yaml
# TODO: Update `update-cluster-template.diff` file when R5 release will be stabilized
if grep -q "SERVICE_CIDR\|POD_CIDR\|# Defragment & backup & trim script for SCS k8s-cluster-api-provider etcd cluster.\|# Allow to configure registry hosts in containerd" cluster-template.yaml; then
  echo "cluster-template.yaml already updated"
else
  # The default template file `cluster-defaults/cluster-template.yaml` of version R4 still references the old `k8s.gcr.io` container registry.
  # In R4, this was fixed by the `fixup_k8sregistry.sh` script which replaces the old registry with the new one: `registry.k8s.io`.
  # As the new registry could be used for any k8s version we force the replacement here. As a side effect, we could use
  # the same patch (diff) file for the default template file `cluster-defaults/cluster-template.yaml` as well for some workload
  # cluster template file `<CLUSTER_NAME>/cluster-template.yaml`.
  sed -i 's/k8s\.gcr\.io/registry.k8s.io/g' cluster-template.yaml
  patch cluster-template.yaml <~/k8s-cluster-api-provider/terraform/files/update/R4_to_R5/update-cluster-template.diff || restore 3
  # Ensure that the directory for containerd registry configs exists and copy a default containerd registry
  # config file that instructs containerd to use registry.scs.community container registry
  # instance as a public mirror of DockerHub. See #432 for further details.
  mkdir -p containerd/hosts
  cp ~/k8s-cluster-api-provider/terraform/files/containerd/docker.io containerd/hosts/docker.io
  # TODO: Investigate whether both generation counters need to be increased when R5 release will be stabilized
  # Increase the generation counter of control plane and worker machines as the `cluster-template.yaml` patches modified control plane and worker nodes templates.
  if test "$CLUSTER_NAME" != "cluster-defaults"; then # Patch needed only when existing cluster is updated
    echo "increasing generation counter of control plane and worker machines in clusterctl.yaml"
    sed -r 's/(^CONTROL_PLANE_MACHINE_GEN: genc)([0-9][0-9])/printf "\1%02d" $((\2+1))/ge' -i clusterctl.yaml || restore 4
    sed -r 's/(^WORKER_MACHINE_GEN: genw)([0-9][0-9])/printf "\1%02d" $((\2+1))/ge' -i clusterctl.yaml || restore 5
  fi
fi
# Update clusterctl.yaml
# TODO: Update below sed commands when R5 release will be stabilized
#   see: git diff 078385c <R5 commit hash> terraform/files/template/clusterctl.yaml.tmpl
if grep -q "SERVICE_CIDR\|POD_CIDR\|CLUSTER_API_OPENSTACK_INSTANCE_CREATE_TIMEOUT" clusterctl.yaml; then
  echo "variables in clusterctl.yaml already updated"
else
  echo "patching variables in clusterctl.yaml"
  # PR#454 Add ability to specify service and pod CIDRs
  sed -i 's/^# Nodes CIDR/# CIDRs/' clusterctl.yaml || restore 6
  sed -i '/^NODE_CIDR/a SERVICE_CIDR: 10.96.0.0\/12\nPOD_CIDR: 192.168.0.0\/16' clusterctl.yaml || restore 7
  # PR#413 Make openstack instance create timeout configurable
  sed -i '/^OPENSTACK_CLOUD_CACERT_B64/a # set OpenStack Instance create timeout (in minutes)\nCLUSTER_API_OPENSTACK_INSTANCE_CREATE_TIMEOUT: 5' clusterctl.yaml || restore 8
fi
# Nginx-ingress controller has been updated to version 1.8.0 in PR#440 and later to 1.8.1. This is a breaking change that includes updates
# of immutable fields. Therefore, if environment contains nginx ingress deployed via k8s-cluster-api-provider
# (variable DEPLOY_NGINX_INGRESS=true) the following k8s resources should be removed before R5 update (https://github.com/kubernetes/ingress-nginx/issues/5884):
if test "$CLUSTER_NAME" != "cluster-defaults"; then # Patch needed only when existing cluster is updated
  if grep -q "DEPLOY_NGINX_INGRESS: true" clusterctl.yaml; then
    KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
    kubectl "$KCONTEXT" delete job ingress-nginx-admission-create -n ingress-nginx
    kubectl "$KCONTEXT" delete job ingress-nginx-admission-patch -n ingress-nginx
  fi
fi

# Remove backup files if everything passed
echo "removing backup files after patch"
rm cluster-template.yaml.backup clusterctl.yaml.backup

# General updates
if test "$CLUSTER_NAME" = "cluster-defaults"; then
  # Install jq
  sudo apt-get update && sudo apt-get install -y jq
fi

echo "update of cluster files from R4 to R5 version has been successfully finished"
