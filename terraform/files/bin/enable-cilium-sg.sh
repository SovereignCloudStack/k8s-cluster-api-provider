#!/bin/bash
. ~/bin/cccfg.inc
COLUMNS=${COLUMNS:-80}
SGS=$(openstack security group list -f value -c ID -c Name | grep "${PREFIX}-${CLUSTER_NAME}-cilium")
if test -z "$SGS"; then
    SGS=$(openstack security group create ${PREFIX}-${CLUSTER_NAME}-cilium -f value -c id -c name)
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
	openstack security group rule create --description "$PREFIX $CLUSTER_NAME $desc" --ingress --ethertype IPv4 --proto $prot --dst-port $port --remote-group $SG $SG --max-width=$COLUMNS
    done
fi
# SD is consumed in cluster-template.yaml
