#!/usr/bin/env bash
# ./configure_containerd_proxy.sh cluster-template.yaml
#
# Script injects containerd proxy config  file into $1 (cluster-template.yaml).
# Script reads proxy configuration from /etc/profile.d/proxy.sh
#
# - Creates temporary YAML file with the proxy config as follows:
#   ```yaml
#   ---
#   path: /etc/systemd/system/containerd.service.d/http-proxy.conf
#   owner: "root:root"
#   permissions: "0644"
#   content: |
#     [Service]
#     Environment="HTTP_PROXY=<$HTTP_PROXY from /etc/profile.d/proxy.sh>"
#     Environment="HTTPS_PROXY=<$HTTP_PROXY from /etc/profile.d/proxy.sh>"
#     Environment="NO_PROXY=<$NO_PROXY from /etc/profile.d/proxy.sh>"
#   ```
# - Injects temporary YAML file into $1 (cluster-template.yaml) file (using `yq` in place edit).
#   Temporary file is injected to the `KubeadmControlPlaneTemplate.spec.template.spec.kubeadmConfigSpec.files` that specifies extra files to be
#   passed to user_data upon creation of control plane nodes and to the `KubeadmConfigTemplate.spec.template.spec.files`
#   that specifies extra files to be passed to user_data upon creation of worker nodes.
# - Removes temporary YAML file
#
# (c) Malte Muench, 11/2023
# SPDX-License-Identifier: Apache-2.0
if test -z "$1"; then echo "ERROR: Need cluster-template.yaml arg" 1>&2; exit 1; fi

. /etc/profile.d/proxy.sh

if [ ! -v HTTP_PROXY ]
then
echo "No HTTP_PROXY set, nothing to do, exiting."
exit 0
fi

export SYSTEMD_CONFIG_CONTENT=containerd_systemd_conf
export CLUSTER_TEMPLATE_SNIPPET=clustertemplate_snippet

echo "[Service]" > $SYSTEMD_CONFIG_CONTENT
echo "Environment=\"HTTP_PROXY=$HTTP_PROXY\"" >> $SYSTEMD_CONFIG_CONTENT
echo "Environment=\"HTTPS_PROXY=$HTTP_PROXY\"" >> $SYSTEMD_CONFIG_CONTENT
echo "Environment=\"NO_PROXY=$NO_PROXY\"" >> $SYSTEMD_CONFIG_CONTENT


yq --null-input '
  .path = "/etc/systemd/system/containerd.service.d/http-proxy.conf" |
  .owner = "root:root" |
  .permissions = "0644" |
  .content = loadstr(env(SYSTEMD_CONFIG_CONTENT))' > $CLUSTER_TEMPLATE_SNIPPET

# Test whether the file is already present in cluster-template.yaml
file_cp_exist=$(yq 'select(.kind == "KubeadmControlPlaneTemplate").spec.template.spec.kubeadmConfigSpec | (.files // (.files = []))[] | select(.path == "/etc/systemd/system/containerd.service.d/http-proxy.conf")' "$1")

if test -z "$file_cp_exist"; then
	echo "Adding containerd proxy config to the KubeadmControlPlaneTemplate files"
	yq 'select(.kind == "KubeadmControlPlaneTemplate").spec.template.spec.kubeadmConfigSpec.files += [load(env(CLUSTER_TEMPLATE_SNIPPET))]' -i "$1"
else
        echo "containerd proxy config is already defined in KubeadmControlPlaneTemplate files"
fi

file_ct_exist=$(yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec | (.files // (.files = []))[] | select(.path == "/etc/systemd/system/containerd.service.d/http-proxy.conf")' "$1")
if test -z "$file_ct_exist"; then
    echo "Adding containerd proxy config to the KubeadmConfigTemplate files"
    yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec.files += [load(env(CLUSTER_TEMPLATE_SNIPPET))]' -i "$1"
else
    echo "containerd proxy config is already defined in KubeadmConfigTemplate files"
fi

rm $SYSTEMD_CONFIG_CONTENT
rm $CLUSTER_TEMPLATE_SNIPPET
exit 0
