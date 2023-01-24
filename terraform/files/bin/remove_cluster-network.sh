#!/bin/bash
export KUBECONFIG=~/.kube/config
. ~/.capi-settings
. ~/bin/cccfg.inc

# Determine mgmtserver networks
MGMT="$PREFIX-mgmtcluster"
MGMTNET=$(openstack server list --name "$MGMT" -f value -c Networks)
NET=$(echo "$MGMTNET" | grep "k8s-clusterapi-cluster-default-$CLUSTER_NAME=" | sed "s/.*k8s-clusterapi-cluster-default-$CLUSTER_NAME=\([0-9a-f:\.]*\).*\$/\1/")
# New format
if test -z "$NET"; then NET=$(echo "$MGMTNET" | grep "'k8s-clusterapi-cluster-default-$CLUSTER_NAME':" | sed "s/.*'k8s-clusterapi-cluster-default-$CLUSTER_NAME':[^']*'\([0-9a-f:\.]*\)'.*\$/\1/"); fi
if test -z "$NET"; then echo "No network to remove ..."; exit 1; fi
NIC=$(ip addr | grep -B4 "inet $NET/" | grep '^[0-9]' | sed 's/^[0-9]*: \([^: ]*\): .*$/\1/')

#sudo ip link set dev ens8 down
echo "Removing NIC $NIC $NET ..."
openstack server remove network $MGMT k8s-clusterapi-cluster-default-$CLUSTER_NAME || exit

