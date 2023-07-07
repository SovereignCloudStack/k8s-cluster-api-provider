#!/usr/bin/env bash
# ./inject_custom_ca.sh cluster-template.yaml CACERT CADEST
#
# Script injects $2 (CACERT) into $1 (cluster-template.yaml).
# CACERT will be injected to k8s nodes on $3 (CADEST) path.
# Inspiration taken from configure_containerd.sh
#
# (c) Roman Hros, 07/2023
# SPDX-License-Identifier: Apache-2.0

if test -z "$1"; then echo "ERROR: Need cluster-template.yaml arg" 1>&2; exit 1; fi
if test -z "$2"; then echo "ERROR: Need CACERT arg" 1>&2; exit 1; fi
if test -z "$3"; then echo "ERROR: Need CADEST arg" 1>&2; exit 1; fi

export CA_FILE="$2"
export CA_DEST="$3"

yq --null-input '
  .path = env(CA_DEST) |
  .owner = "root:root" |
  .permissions = "0644" |
  .encoding = "base64" |
  .content = (loadstr(env(CA_FILE)) | @base64)
  ' > file_tmp

yq 'select(.kind == "KubeadmControlPlane").spec.kubeadmConfigSpec.files += [load("file_tmp")]' -i "$1"
yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec.files += [load("file_tmp")]' -i "$1"

rm file_tmp
