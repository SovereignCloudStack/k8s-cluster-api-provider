#!/bin/bash
export KUBECONFIG=~/.kube/config
. ~/bin/cccfg.inc

#
MGMT=$(openstack server list --name ".*\-mgmtcluster" -f value -c Name)
#sudo ip link set dev ens8 down
echo "Removing NIC ..."
openstack server remove network $MGMT k8s-clusterapi-cluster-default-$CLUSTER_NAME || exit

