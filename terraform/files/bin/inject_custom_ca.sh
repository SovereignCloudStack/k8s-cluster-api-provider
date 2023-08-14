#!/usr/bin/env bash
# ./inject_custom_ca.sh cluster-template.yaml CADEST
#
# Script injects cacert (file with content from secret ${CLUSTER_NAME}-cloud-config) into $1 (cluster-template.yaml).
# Secret ${CLUSTER_NAME}-cloud-config contains key cacert with OPENSTACK_CLOUD_CACERT_B64 variable.
# Cacert will be templated later and injected to k8s nodes on $2 (CADEST) path.
# Inspiration taken from configure_containerd.sh
#
# (c) Roman Hros, 07/2023
# SPDX-License-Identifier: Apache-2.0

if test -z "$1"; then echo "ERROR: Need cluster-template.yaml arg" 1>&2; exit 1; fi
if test -z "$2"; then echo "ERROR: Need CADEST arg" 1>&2; exit 1; fi

export CA_DEST="$2"

yq --null-input '
  .path = env(CA_DEST) |
  .owner = "root:root" |
  .permissions = "0644" |
  .contentFrom = {"secret": {"key": "cacert", "name": "${CLUSTER_NAME}-cloud-config"}}
  ' > file_tmp

yq 'select(.kind == "KubeadmControlPlane").spec.kubeadmConfigSpec.files += [load("file_tmp")]' -i "$1"
yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec.files += [load("file_tmp")]' -i "$1"

rm file_tmp
