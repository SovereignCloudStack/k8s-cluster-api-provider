#!/usr/bin/env bash
# ./configure_containerd_proxy.sh cluster-template.yaml
#
# Script injects proxy profile config  file into $1 (cluster-template.yaml).
# Script reads proxy configuration from /etc/profile.d/proxy.sh
#
# - Creates temporary YAML file with the proxy config as follows:
#   ```yaml
#   ---
#   path: /etc/profile.d/proxy.sh
#   owner: "root:root"
#   permissions: "0644"
#   content: |
#   <content form /etc/profile.d/proxy.sh>
#   ```
# - Injects temporary YAML file into $1 (cluster-template.yaml) file (using `yq` in place edit).
#   Temporary file is injected to the `KubeadmControlPlane.spec.kubeadmConfigSpec.files` that specifies extra files to be
#   passed to user_data upon creation of control plane nodes and to the `KubeadmConfigTemplate.spec.template.spec.files`
#   that specifies extra files to be passed to user_data upon creation of worker nodes.
# - Removes temporary YAML file
#
# (c) Malte Muench, 11/2023
# SPDX-License-Identifier: Apache-2.0
if test -z "$1"; then echo "ERROR: Need cluster-template.yaml arg" 1>&2; exit 1; fi

. /etc/profile.d/proxy.sh

export PROFILE_CONFIG_CONTENT=/etc/profile.d/proxy.sh
export CLUSTER_TEMPLATE_SNIPPET=clustertemplate_snippet


yq --null-input '
  .path = "/etc/profile.d/proxy.sh" |
  .owner = "root:root" |
  .permissions = "0644" |
  .content = loadstr(env(PROFILE_CONFIG_CONTENT))' > $CLUSTER_TEMPLATE_SNIPPET

# Test whether the file is already present in cluster-template.yaml
file_cp_exist=$(yq 'select(.kind == "KubeadmControlPlane").spec.kubeadmConfigSpec | (.files // (.files = []))[] | select(.path == "/etc/profile.d/proxy.sh")' "$1")

if test -z "$file_cp_exist"; then
	echo "Adding containerd proxy config to the KubeadmControlPlane files"
	yq 'select(.kind == "KubeadmControlPlane").spec.kubeadmConfigSpec.files += [load(env(CLUSTER_TEMPLATE_SNIPPET))]' -i "$1"
else
        echo "proxy profile config is already defined in KubeadmControlPlane files"
fi

file_ct_exist=$(yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec | (.files // (.files = []))[] | select(.path == "/etc/profile.d/proxy.sh")' "$1")
if test -z "$file_ct_exist"; then
    echo "Adding containerd proxy config to the KubeadmConfigTemplate files"
    yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec.files += [load(env(CLUSTER_TEMPLATE_SNIPPET))]' -i "$1"
else
    echo "proxy profile config is already defined in KubeadmConfigTemplate files"
fi

rm $PROFILE_CONFIG_CONTENT
rm $CLUSTER_TEMPLATE_SNIPPET
exit 0
