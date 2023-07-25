#!/bin/bash
# File to be sourced to get a numeric k8s version
# parse_k8s_version.inc 
#
# (c) Kurt Garloff <kurt@garloff.de>, 2/2023
# SPDX-License-Identifer: Apache-2.0
#
# We parse the KUBERNETES_VERSION in clusterctl.yaml from $CCCFG
# and create K8SMAJOR, K8SMINOR, K8SPATCH and K8SVER for the environment
# K8SVER is a number with 10000*$K8SMAJOR+100*$K8SMINOR+$K8SPATCH
# This parser is robust against omitted patch levels (assuming 0 then)

K8SVER=$(grep '^KUBERNETES_VERSION:' "$CCCFG" | sed 's/^KUBERNETES_VERSION: v\([0-9.]*\)/\1/')
K8SMINOR=${K8SVER#*.}
K8SPATCH=${K8SMINOR#*.}
# Avoid omitted patchlevel being mistreated
if test "$K8SPATCH" = "$K8SMINOR"; then K8SPATCH=0; fi
K8SMINOR=${K8SMINOR%%.*}
K8SMAJOR=${K8SVER%%.*}
K8SVER=${K8SMAJOR}$(printf %02i ${K8SMINOR})$(printf %02i ${K8SPATCH})
