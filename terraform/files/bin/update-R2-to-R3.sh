#!/bin/bash
# Apply patches to cluster-template.yaml and clusterctl.yaml
# (c) Kurt Garloff <garloff@osb-alliance.com>, 7/2022
# SPDX-License-Identifier: Apache-2.0

usage()
{
	echo "Usage: update-R2-to-R3.sh CLUSTERNAME"
	echo "Updates the cluster-template.yaml and clusterctl.yaml to have the new"
	echo "variables CONTROL_PLANE_MACHINE_GEN and WORKER_MACHINE_GEN"
	exit 1
}

CLUSTER_NAME="$1"
if test -z "$CLUSTER_NAME"; then usage; fi

restore()
{
	echo "Patching failed ($1)" 1>&2
	cp -p cluster-template.yaml.backup cluster-template.yaml
	cp -p clusterctl.yaml.backup clusterctl.yaml
	exit $1
}

cd ~/${CLUSTER_NAME} || { echo "Cluster config $CLUSTER_NAME does not exist" 1>&2; exit 2; }
if test ! -r cluster-template.yaml -o ! -r clusterctl.yaml; then echo "cluster-template.yaml or clusterctl.yaml not found" 1>&2; exit 3; fi
# Backup
cp -p cluster-template.yaml cluster-template.yaml.backup
cp -p clusterctl.yaml clusterctl.yaml.backup
# cluster-template
patch -R --dry-run cluster-template.yaml < ~/k8s-cluster-api-provider/terraform/files/update/R2_to_R3/update-cluster-template.diff >/dev/null 2>&1
if test $? == 0; then
	echo "cluster-template.yaml already upgraded" 1>&2
else
	patch cluster-template.yaml < ~/k8s-cluster-api-provider/terraform/files/update/R2_to_R3/update-cluster-template.diff || restore 4
fi
# CONTROL_PLANE_MACHINE_GEN
if grep '^CONTROL_PLANE_MACHINE_GEN' clusterctl.yaml >/dev/null 2>&1; then
	echo "CONTROL_PLANE_MACHINE_GEN already set in clusterctl.yaml" 1>&2
else
	sed -i -f ~/k8s-cluster-api-provider/terraform/files/update/R2_to_R3/update-clusterctl-control-gen.sed clusterctl.yaml || restore 5
fi
# WORKER_MACHINE_GEN
if grep '^WORKER_MACHINE_GEN' clusterctl.yaml >/dev/null 2>&1; then
	echo "WORKER_MACHINE_GEN already set in clusterctl.yaml" 1>&2
else
	sed -i -f ~/k8s-cluster-api-provider/terraform/files/update/R2_to_R3/update-clusterctl-worker-gen.sed clusterctl.yaml || restore 6
fi
rm cluster-template.yaml.backup clusterctl.yaml.backup


