#!/bin/bash
# Install k8s-cluster-api-provider repo
# Optional args: branch and patch
# (c) Kurt Garloff <garloff@osb-alliance.com>, 3/2022
# SPDX-License-Identifier: Apache-2.0
. /etc/profile.d/proxy.sh
cd
getent hosts github.com || sleep 30
#cd k8s-cluster-api-provider
if test -n "$1"; then git clone "$1" k8s-cluster-api-provider || exit 1; fi
cd k8s-cluster-api-provider
if test -n "$2"; then git checkout "$2" || exit 1; fi
if test -n "$3"; then patch -p1 <"$3" || exit 1; fi
cd 
# Create links
ln -s k8s-cluster-api-provider/terraform/files/bin .
ln -s k8s-cluster-api-provider/terraform/files/kubernetes-manifests.d .
mkdir ~/doc
ln -s ../k8s-cluster-api-provider/README.md ~/doc
ln -s ~/k8s-cluster-api-provider/Release-Notes*.md ~/doc

