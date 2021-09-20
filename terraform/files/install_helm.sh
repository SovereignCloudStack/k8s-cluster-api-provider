#!/bin/bash
# Download and deploy helm

HELMVER=3.7.0
curl -LO https://get.helm.sh/helm-v${HELMVER}-linux-amd64.tar.gz
tar xvzf helm-v${HELMVER}-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/
rm helm-v${HELMVER}-linux-amd64.tar.gz

