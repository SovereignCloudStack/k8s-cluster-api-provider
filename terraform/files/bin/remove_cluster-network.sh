#!/bin/bash
export KUBECONFIG=~/.kube/config
. ~/.capi-settings
. ~/bin/cccfg.inc

NET_NAME=$(openstack network list -f value -c Name | grep "k8s-clusterapi-cluster-\(default-${CLUSTER_NAME}\|${CLUSTER_NAME}-${CLUSTER_NAME}\)")

# Determine mgmtserver networks
MGMT="$PREFIX-mgmtcluster"
MGMTNET=$(openstack server list --name "$MGMT" -f value -c Networks)
if [[ $NET_NAME == "k8s-clusterapi-cluster-default-"* ]]; then
  # Old format of network name based on cluster in default namespace
  NET=$(echo "$MGMTNET" | grep "k8s-clusterapi-cluster-default-$CLUSTER_NAME=" | sed "s/.*k8s-clusterapi-cluster-default-$CLUSTER_NAME=\([0-9a-f:\.]*\).*\$/\1/")
  # New format
  if test -z "$NET"; then NET=$(echo "$MGMTNET" | grep "'k8s-clusterapi-cluster-default-$CLUSTER_NAME':" | sed "s/.*'k8s-clusterapi-cluster-default-$CLUSTER_NAME':[^']*'\([0-9a-f:\.]*\)'.*\$/\1/"); fi
else
  # New format of network name based on cluster in cluster with namespace name as cluster name
  NET=$(echo "$MGMTNET" | grep "k8s-clusterapi-cluster-$CLUSTER_NAME-$CLUSTER_NAME=" | sed "s/.*k8s-clusterapi-cluster-$CLUSTER_NAME-$CLUSTER_NAME=\([0-9a-f:\.]*\).*\$/\1/")
  # New format
  if test -z "$NET"; then NET=$(echo "$MGMTNET" | grep "'k8s-clusterapi-cluster-$CLUSTER_NAME-$CLUSTER_NAME':" | sed "s/.*'k8s-clusterapi-cluster-$CLUSTER_NAME-$CLUSTER_NAME':[^']*'\([0-9a-f:\.]*\)'.*\$/\1/"); fi
fi
if test -z "$NET"; then
  echo "No network to remove ..."
  exit 1
fi
NIC=$(ip addr | grep -B4 "inet $NET/" | grep '^[0-9]' | sed 's/^[0-9]*: \([^: ]*\): .*$/\1/')

#sudo ip link set dev ens8 down
echo "Removing NIC $NIC $NET ..."
openstack server remove network $MGMT $NET_NAME || exit
