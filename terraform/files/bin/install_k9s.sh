#!/bin/bash
# Deploy k9s on mgmt cluster for convenience
# (c) Kurt Garloff / Malte Münch / Thosten Schifferdecker 1/2021 -- 2/2022
# SPDX-License-Identifier: CC-BY-SA-4.0

# install k9s
echo "# install latest k9s"
ARCH=$(uname -m)
# TODO: Check signature
curl -L https://github.com/derailed/k9s/releases/latest/k9s_Linux_$ARCH.tar.gz | tar zf - -x k9s
sudo mv ./k9s /usr/local/bin/k9s

