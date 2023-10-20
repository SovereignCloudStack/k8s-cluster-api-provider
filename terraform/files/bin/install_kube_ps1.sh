#!/usr/bin/env bash

KUBEPS1_VERSION=v0.8.0
echo "# install kube-ps1 $KUBEPS1_VERSION"
git clone --depth 1 --branch $KUBEPS1_VERSION https://github.com/jonmosco/kube-ps1 ~/.kube-ps1