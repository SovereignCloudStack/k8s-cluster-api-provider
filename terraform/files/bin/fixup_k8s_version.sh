#!/bin/bash
# fixup_k8s_version.sh
# Patch $1 (clusterctl.yaml) with fixed up k8s version if needed
# (c) Kurt Garloff, 03/2022
# SPDX-License-Identifier: Apache-2.0

if test -z "$1"; then echo "ERROR: Need clusterctl.yaml arg" 1>&2; exit 1; fi
KUBERNETES_VERSION=$(yq eval '.KUBERNETES_VERSION' $1)
if test "${KUBERNETES_VERSION:$((${#KUBERNETES_VERSION}-1)):1}" != "x"; then exit 0; fi
. ~/bin/openstack-kube-versions.inc
k8s=$KUBERNETES_VERSION
set_k8s_latestpatch $KUBERNETES_VERSION
echo "Correct k8s from $k8s to $KUBERNETES_VERSION"
sed -i "s/KUBERNETES_VERSION:\([^v]*\)v[^x]*x/KUBERNETES_VERSION:\1$KUBERNETES_VERSION/" $1
sed -i "s/OPENSTACK_IMAGE_NAME:\(.*\)\-v[^x]*x/OPENSTACK_IMAGE_NAME:\1-$KUBERNETES_VERSION/" $1

