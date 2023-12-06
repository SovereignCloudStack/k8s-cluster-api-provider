#!/bin/bash
# Download and deploy helm

HELMVER=3.12.3
OS=linux; ARCH=$(uname -m | sed 's/x86_64/amd64/')
curl -LO https://get.helm.sh/helm-v${HELMVER}-$OS-$ARCH.tar.gz
tar xvzf helm-v${HELMVER}-$OS-$ARCH.tar.gz
sudo mv $OS-$ARCH/helm /usr/local/bin/
rm helm-v${HELMVER}-$OS-$ARCH.tar.gz
rm -rf $OS-$ARCH

