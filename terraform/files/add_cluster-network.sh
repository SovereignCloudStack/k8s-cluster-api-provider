#!/bin/bash
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
#NAMESPACE=$(yq eval .NAMESPACE $CCCFG)
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}" # "--namespace=$NAMESPACE"
#
MGMT=$(openstack server list --name ".*\-mgmtcluster" -f value -c Name)
openstack server add network $MGMT k8s-clusterapi-cluster-default-$CLUSTER_NAME || exit
WAIT=0
while test $WAIT -lt 30; do
	ip link show ens8 >/dev/null 2>&1
	if test $? = 0; then break; fi
	sleep 1
	let WAIT+=1
done
#sudo dhclient ens8
#sudo ip route del default via 10.8.0.1 dev ens8
#sudo ip route del default dev ens8
MAC=$(ip link show ens8 | grep 'link/ether' | sed 's/^ *link\/ether \([0-9a-f:]*\) .*$/\1/')
IP=$(openstack port list --mac=$MAC -f value -c 'Fixed IP Addresses' | sed "s/^.*'ip_address': '\([0-9\.]*\)'.*\$/\1/")
NETMASK=$(grep NODE_CIDR clusterctl-${CLUSTER_NAME}.yaml clusterctl.yaml | head -n 1 | sed 's/^.*NODE_CIDR: //')
NETMASK=${NETMASK#*/}
sudo ip link set dev ens8 up
sudo ip add add $IP/$NETMASK dev ens8
