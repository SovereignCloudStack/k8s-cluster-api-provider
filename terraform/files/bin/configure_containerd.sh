#!/usr/bin/env bash
# ./configure_containerd.sh cluster-template.yaml $CLUSTER_NAME
#
# Script injects containerd registry host and cert files into $1 (cluster-template.yaml).
# Script reads files located in directories $HOME/$CLUSTER_NAME/containerd/hosts and
# $HOME/$CLUSTER_NAME/containerd/certs and then executes the following on each:
#
# - Composes full destination path of the file (i.e. path on cluster node). The full path is composed as follows:
#   - Host file (file is stored in the `hosts.toml` file in the subdirectory created based on its filename):
#     <`host` file directory (`/etc/containerd/certs.d/`)> + <subdirectory named as file> + <hosts.toml>
#   - Cert file (file is stored as it is in a dedicated directory):
#     <`cert` file directory (`/etc/containerd/certs/`)> + <filename>
# - Creates temporary YAML file from the file content with destination path from above as follows:
#   ```yaml
#   ---
#   path: <full path on k8s node where to store the file>
#   owner: "root:root"
#   permissions: "0644"
#   content: |
#     <file content>
#   ```
# - Injects temporary YAML file into $1 (cluster-template.yaml) file (using `yq` in place edit).
#   Temporary file is injected to the `KubeadmControlPlaneTemplate.spec.template.spec.kubeadmConfigSpec.files` that specifies extra files to be
#   passed to user_data upon creation of control plane nodes and to the `KubeadmConfigTemplate.spec.template.spec.files`
#   that specifies extra files to be passed to user_data upon creation of worker nodes.
# - Removes temporary YAML file
#
# (c) Matej Feder, 06/2023
# SPDX-License-Identifier: Apache-2.0

if test -z "$1"; then echo "ERROR: Need cluster-template.yaml arg" 1>&2; exit 1; fi
if test -z "$2"; then echo "ERROR: Need CLUSTER_NAME arg" 1>&2; exit 1; fi

declare -a paths
paths=("hosts" "certs")

for path in "${paths[@]}"; do
  for file in "$HOME"/"$2"/containerd/"$path"/*; do
    export file
    if [ -f "$file" ]; then

      if [ "$path" = "hosts" ]; then
        file_name="$(basename "$file")/hosts.toml"
        destination_path="/etc/containerd/certs.d/"
        export destination_path file_name
      fi

      if [ "$path" = "certs" ]; then
        file_name=$(basename "$file")
        destination_path="/etc/containerd/certs/"
        export destination_path file_name
      fi

      yq --null-input '
        .path = env(destination_path) + env(file_name) |
        .owner = "root:root" |
        .permissions = "0644" |
        .content = loadstr(env(file))
        ' > file_tmp
      # Evaluate whether the file is already present in the cluster-template.yaml.
      # YAML key `files` is not mandatory therefore it should be added as an empty array to ensure that the whole evaluation will work as expected,
      # see related YQ docs: https://mikefarah.gitbook.io/yq/operators/alternative-default-value#update-or-create-entity-does-not-exist
      file_cp_exist=$(yq 'select(.kind == "KubeadmControlPlaneTemplate").spec.template.spec.kubeadmConfigSpec | (.files // (.files = []))[] | select(.path == env(destination_path) + env(file_name))' "$1")
      if test -z "$file_cp_exist"; then
        echo "Adding $file_name to the KubeadmControlPlaneTemplate files"
        yq 'select(.kind == "KubeadmControlPlaneTemplate").spec.template.spec.kubeadmConfigSpec.files += [load("file_tmp")]' -i "$1"
      else
        echo "$file_name is already defined in KubeadmControlPlaneTemplate files"
      fi
      file_ct_exist=$(yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec | (.files // (.files = []))[] | select(.path == env(destination_path) + env(file_name))' "$1")
      if test -z "$file_ct_exist"; then
        echo "Adding $file_name to the KubeadmConfigTemplate files"
        yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec.files += [load("file_tmp")]' -i "$1"
      else
        echo "$file_name is already defined in KubeadmConfigTemplate files"
      fi
      rm file_tmp
    fi
  done
done
