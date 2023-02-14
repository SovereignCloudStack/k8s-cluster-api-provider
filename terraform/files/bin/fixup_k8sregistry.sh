#!/bin/bash
# fixup_k8s_version.sh
# Patch $2 (cluster-template.yaml) with fixed up k8s imageRepo if needed
# This is to find old kube-proxy, coredns, ... images on k8s.gcr.io and new ones on registry.k8s.io
# See https://github.com/kubernetes-sigs/cluster-api/blob/main/internal/util/kubeadm/kubeadm.go#L40
# (c) Kurt Garloff, Roman Hros, 02/2023
# SPDX-License-Identifier: Apache-2.0

if test -z "$2"; then echo "ERROR: Need clusterctl.yaml cluster-template args" 1>&2; exit 1; fi
K8SVER=$(grep '^KUBERNETES_VERSION:' "$1" | sed 's/^KUBERNETES_VERSION: v\([0-9.]*\)/\1/')
K8SMINOR=${K8SVER#*.}
K8SPATCH=${K8SMINOR#*.}
if test "$K8SPATCH" = "$K8SMINOR"; then K8SPATCH=0; fi
K8SMINOR=${K8SMINOR%%.*}
K8SVER=${K8SVER%%.*}$(printf %02i ${K8SMINOR})$(printf %02i ${K8SPATCH})
#echo $K8SVER
if grep 'k8s\.gcr\.io' "$2" >/dev/null 2>&1; then
    if test "$K8SVER" -ge 12409 \
	|| test "$K8SVER" -lt 12400 -a "$K8SVER" -ge 12315 \
	|| test "$K8SVER" -lt 12300 -a "$K8SVER" -ge 12217; then
	sed -i 's/k8s\.gcr\.io/registry.k8s.io/g' "$2"
    fi
fi
