#!/bin/bash
CLUSTER=testcluster
if test -n "$1"; then CLUSTER="$1"; fi
SGS=$(openstack security group list -f value -c ID -c Name | grep "k8s-cluster-default-${CLUSTER}-secgroup-")
SG_WORKER=$(echo "$SGS" | grep worker | cut -d " " -f1)
SG_CONTROL=$(echo "$SGS" | grep controlplane | cut -d " " -f1)
#rm -f enable-cilium-control.yaml enable-cilium-worker.yaml
echo -e "status:\n controlPlaneSecurityGroup:\n  rules:" > enable-cilium-control.yaml
echo -e "status:\n workerSecurityGroup:\n  rules:" > enable-cilium-worker.yaml
for proto in udp/8472/VXLAN tcp/4240/HealthCheck tcp/31813/EchoOther tcp/31374/EchoSame; do
	prot=${proto%%/*}
	port=${proto#*/}
	desc="${port#*/} (cilium)"
	port=${port%/*}
	#openstack security group rule create --description "capi $CLUSTER $desc" --ingress --ethertype IPv4 --proto $prot --dst-port $port:$port --remote-group $SG_WORKER $SG_WORKER
	#openstack security group rule create --description "capi $CLUSTER $desc" --ingress --ethertype IPv4 --proto $prot --dst-port $port:$port --remote-group $SG_WORKER $SG_CONTROL
	#openstack security group rule create --description "capi $CLUSTER $desc" --ingress --ethertype IPv4 --proto $prot --dst-port $port:$port --remote-group $SG_CONTROL $SG_WORKER
	#openstack security group rule create --description "capi $CLUSTER $desc" --ingress --ethertype IPv4 --proto $prot --dst-port $port:$port --remote-group $SG_CONTROL $SG_CONTROL
	echo -e "   - description: capi $CLUSTER $desc\n     direction: ingress\n     etherType: IPv4\n     protocol: $prot\n     portRangeMin: ${port%:*}\n     portRangeMax: ${port##*:}\n     remoteGroupID: $SG_WORKER" >>  enable-cilium-control.yaml
	echo -e "   - description: capi $CLUSTER $desc\n     direction: ingress\n     etherType: IPv4\n     protocol: $prot\n     portRangeMin: ${port%:*}\n     portRangeMax: ${port##*:}\n     remoteGroupID: $SG_CONTROL" >>  enable-cilium-control.yaml
	echo -e "   - description: capi $CLUSTER $desc\n     direction: ingress\n     etherType: IPv4\n     protocol: $prot\n     portRangeMin: ${port%:*}\n     portRangeMax: ${port##*:}\n     remoteGroupID: $SG_WORKER" >>  enable-cilium-worker.yaml
	echo -e "   - description: capi $CLUSTER $desc\n     direction: ingress\n     etherType: IPv4\n     protocol: $prot\n     portRangeMin: ${port%:*}\n     portRangeMax: ${port##*:}\n     remoteGroupID: $SG_CONTROL" >>  enable-cilium-worker.yaml
done
kubectl --context=kind-kind patch openstackcluster "$CLUSTER" --type=merge --patch-file enable-cilium-control.yaml
kubectl --context=kind-kind patch openstackcluster "$CLUSTER" --type=merge --patch-file enable-cilium-worker.yaml
