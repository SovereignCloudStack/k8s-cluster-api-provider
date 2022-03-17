#!/bin/bash
# Install k8s-cluster-api-provider repo
# Optional args: branch and patch
# (c) Kurt Garloff <garloff@osb-alliance.com>, 3/2022
# SPDX-License-Identifier: CC-BY-SA-4.9
cd
git clone https://github.com/SovereignCloudStack/k8s-cluster-api-provider || exit 1
cd k8s-cluster-api-provider
if test -n "$1"; then git checkout "$1" || exit 1; fi
if test -n "$2"; then patch -p1 <"$2" || exit 1; fi
cd 
# Create links
ln -s k8s-cluster-api-provider/terraform/files/bin .
ln -s k8s-cluster-api-provider/terraform/files/kubernetes-manifests.d .

