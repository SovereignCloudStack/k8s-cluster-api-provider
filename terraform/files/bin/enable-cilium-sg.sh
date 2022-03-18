#!/bin/bash
. ~/bin/cccfg.inc
SGS=$(openstack security group list -f value -c ID -c Name | grep "k8s-cluster-${CLUSTER_NAME}-cilium")
if test -z "$SGS"; then
    SGS=$(openstack security group create k8s-cluster-${CLUSTER_NAME}-cilium -f value -c id -c name)
    # Note: Silium connectivity test will requires tcp/3xxxx/EchoOther tcp/3xxxx/EchoSame
    # See ports with k get svc -A
    # Should this really be required?
    #SG=${SGS%% *}
    SG=$(echo "$SGS" | head -n1)
    for proto in udp/8472/VXLAN tcp/4240/HealthCheck tcp/4244/Hubble; do
	prot=${proto%%/*}
	port=${proto#*/}
	desc="${port#*/} (cilium)"
	port=${port%/*}
	if test "${port%:*}" == "$port"; then port="$port:$port"; fi
	# Note: we could instead use --remote-ip ${NODE_CIDR} -- less secure, but better performance
	openstack security group rule create --description "capi $CLUSTER_NAME $desc" --ingress --ethertype IPv4 --proto $prot --dst-port $port --remote-group $SG $SG
    done
fi
# SD is consumed in cluster-template.yaml
