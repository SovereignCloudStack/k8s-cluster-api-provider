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
#     Environment="NO_PROXY=<my-no-proxy-configuration>"
#   ```
# - Injects temporary YAML file into $1 (cluster-template.yaml) file (using `yq` in place edit).
#   Temporary file is injected to the `KubeadmControlPlane.spec.kubeadmConfigSpec.files` that specifies extra files to be
#   passed to user_data upon creation of control plane nodes and to the `KubeadmConfigTemplate.spec.template.spec.files`
#   that specifies extra files to be passed to user_data upon creation of worker nodes.
# - Removes temporary YAML file
#
# (c) Malte Muench, 11/2023
# SPDX-License-Identifier: Apache-2.0

. /etc/profile.d/proxy.sh

if [ -v $HTTP_PROXY ]
then
echo "I am going to set $HTTP_PROXY as the proxy server for containerd"
fi

exit 0
