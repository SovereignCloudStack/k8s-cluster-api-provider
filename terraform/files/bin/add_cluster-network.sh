#!/bin/bash
# Attach a port from the workload cluster network to the mgmtcluster node
# so we can talk to the nodes (ssh login, ...) -- for debugging only
# (c) Kurt Garloff <garloff@osb-alliance.com>, 1/2022
# SPDX-License-Identifier: Apache-2.0
export KUBECONFIG=~/.kube/config
. ~/.capi-settings
. ~/bin/cccfg.inc
#NAMESPACE=$(yq eval .NAMESPACE $CCCFG)
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}" # "--namespace=$NAMESPACE"
#

OLDNICLIST=($(ls /sys/class/net | sort))
findnewnic()
{
	NEWNIC=""
	NEWNICLIST=($(ls /sys/class/net | sort))
	for i in $(seq 0 ${#NEWNICLIST[*]}); do
		if test "${NEWNICLIST[$i]}" != "${OLDNICLIST[$i]}"; then
			NEWNIC="${NEWNICLIST[$i]}"
			return 0
		fi
	done
	return 1
}

MGMT=$(openstack server list --name "$PREFIX-mgmtcluster" -f value -c Name)
openstack server add network $MGMT k8s-clusterapi-cluster-default-$CLUSTER_NAME || exit
WAIT=0
while test $WAIT -lt 30; do
	findnewnic
	if test $? = 0; then break; fi
	sleep 1
	let WAIT+=1
done
#sudo dhclient $NEWNIC
#sudo ip route del default via 10.8.0.1 dev $NEWNIC
#sudo ip route del default dev $NEWNIC
MAC=$(ip link show $NEWNIC | grep 'link/ether' | sed 's/^ *link\/ether \([0-9a-f:]*\) .*$/\1/')
IP=$(openstack port list --mac=$MAC -f value -c 'Fixed IP Addresses' | sed "s/^.*'ip_address': '\([0-9\.]*\)'.*\$/\1/")
NETMASK=$(grep NODE_CIDR "$CCCFG" | head -n 1 | sed 's/^.*NODE_CIDR: //')
NETMASK=${NETMASK#*/}
sudo ip link set dev $NEWNIC up
sudo ip add add $IP/$NETMASK dev $NEWNIC
echo "Added NIC $NEWNIC (MAC $MAC) with addr $IP/$NETMASK"
