#!/usr/bin/env bash
# ./configure_proxy.sh cluster-template.yaml clusterctl.yaml
#
# Script injects proxy profile config  file into $1 (cluster-template.yaml) and proxy command into $2 (clusterctl.yaml).
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
#   Temporary file is injected to the `KubeadmControlPlaneTemplate.spec.kubeadmConfigSpec.files` that specifies extra files to be
#   passed to user_data upon creation of control plane nodes and to the `KubeadmConfigTemplate.spec.template.spec.files`
#   that specifies extra files to be passed to user_data upon creation of worker nodes.
# - Removes temporary YAML file
# - Sets PROXY_CMD in $2 (clusterctl.yaml)
#
# (c) Malte Muench, 11/2023
# SPDX-License-Identifier: Apache-2.0
if test -z "$1"; then echo "ERROR: Need cluster-template.yaml arg" 1>&2; exit 1; fi
if test -z "$2"; then echo "ERROR: Need clusterctl.yaml arg" 1>&2; exit 1; fi

. /etc/profile.d/proxy.sh

if [ ! -v HTTP_PROXY ]
then
echo "No HTTP_PROXY set, nothing to do, exiting."
exit 0
fi

export PROFILE_CONFIG_CONTENT=proxy-profile.sh
export CLUSTER_TEMPLATE_SNIPPET=clustertemplate_snippet

# yq might be installed as snap which can not read /etc
cp /etc/profile.d/proxy.sh $PROFILE_CONFIG_CONTENT


yq --null-input '
  .path = "/etc/profile.d/proxy.sh" |
  .owner = "root:root" |
  .permissions = "0644" |
  .content = loadstr(env(PROFILE_CONFIG_CONTENT))' > $CLUSTER_TEMPLATE_SNIPPET

# Test whether the file is already present in cluster-template.yaml
file_cp_exist=$(yq 'select(.kind == "KubeadmControlPlaneTemplate").spec.template.spec.kubeadmConfigSpec | (.files // (.files = []))[] | select(.path == "/etc/profile.d/proxy.sh")' "$1")

if test -z "$file_cp_exist"; then
	echo "Adding proxy config to the KubeadmControlPlaneTemplate files"
	yq 'select(.kind == "KubeadmControlPlaneTemplate").spec.template.spec.kubeadmConfigSpec.files += [load(env(CLUSTER_TEMPLATE_SNIPPET))]' -i "$1"
else
        echo "proxy profile config is already defined in KubeadmControlPlaneTemplate files"
fi

file_ct_exist=$(yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec | (.files // (.files = []))[] | select(.path == "/etc/profile.d/proxy.sh")' "$1")
if test -z "$file_ct_exist"; then
    echo "Adding proxy config to the KubeadmConfigTemplate files"
    yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec.files += [load(env(CLUSTER_TEMPLATE_SNIPPET))]' -i "$1"
else
    echo "proxy profile config is already defined in KubeadmConfigTemplate files"
fi

rm $PROFILE_CONFIG_CONTENT
rm $CLUSTER_TEMPLATE_SNIPPET

yq eval '.PROXY_CMD = ". /etc/profile.d/proxy.sh; " | .PROXY_CMD style="double"' -i "$2"
exit 0
