#!/bin/bash
CLUSTER=testcluster
if test -n "$1"; then CLUSTER="$1"; fi
SGS=$(openstack security group list -f value -c ID -c Name | grep "k8s-cluster-${CLUSTER}-cilium")
if test -z "$SGS"; then
    SGS=$(openstack security group create k8s-cluster-${CLUSTER}-cilium -f value -c id -c name)
    SG=${SGS%% *}
    for proto in udp/8472/VXLAN tcp/4240/HealthCheck tcp/31813/EchoOther tcp/31374/EchoSame; do
	prot=${proto%%/*}
	port=${proto#*/}
	desc="${port#*/} (cilium)"
	port=${port%/*}
	if test "${port%:*}" == "$port"; then port="$port:$port"; fi
	# Note: we could instead use --remote-ip ${NODE_CIDR} -- less secure, but better performance
	openstack security group rule create --description "capi $CLUSTER $desc" --ingress --ethertype IPv4 --proto $prot --dst-port $port --remote-group $SG $SG
    done
fi
# SD is consumed in cluster-template.yaml
