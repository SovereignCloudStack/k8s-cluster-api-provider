#!/bin/bash
# Deploy k9s on mgmt cluster for convenience
# (c) Kurt Garloff / Malte Münch / Thosten Schifferdecker 1/2021 -- 2/2022
# SPDX-License-Identifier: Apache-2.0

# install k9s
K9S_VERSION=v0.27.4 # renovate: datasource=github-releases depName=derailed/k9s
echo "# install k9s $K9S_VERSION"
ARCH=$(uname -m | sed 's/x86_64/amd64/')
# TODO: Check signature
#REDIR=$(curl --silent https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name)
#VERSION=$(echo $REDIR | sed -E 's/.*"([^"]+)".*/\1/')
cd ~
curl -L https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_$ARCH.tar.gz | tar xzvf -
sudo mv ./k9s /usr/local/bin/k9s
mv README.md ~/doc/README-k9s-$K9S_VERSION.md
mv LICENSE ~/doc/LICENSE-k9s-$K9S_VERSION
