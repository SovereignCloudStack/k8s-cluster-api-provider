#!/bin/bash
#
# Cleanup script for SCS k8s-cluster-api-provider
#
# Unlike ospurge, this only cleans up what comes from the provider
#
# (c) Kurt Garloff <garloff@osb-alliance.com>, 8/2021
# SPDX-License-Identifier: Apache-2.0
#
# Usage: cleanup.sh [--full] [CLUSTERNAME] [PREFIX]

if test -z "$OPENSTACK"; then OPENSTACK="openstack"; fi

declare -i DELETED=0

# collect list of resources, filtering for names
# $1 => type (can be several strings separated by spaces, e.g. "loadbalancer listener")
# $2 => filter (optional)
# $3 => argument (optional)
# $4 => additional argument to return (optional)
# return value: 0 success, 1 error
# outputs list of UUIDs, one per line
# if $4 is passed, extra results are returned in second field per line

resourcelist()
{
	case "$1" in
		loadbalancer*)
			VALS="-c id -c name" ;;
		keypair)
			VALS="-c Name" ;;
		*)
			VALS="-c ID -c Name" ;;
	esac
	EXTRA=""; if test -n "$4"; then EXTRA="-c $4"; fi
	if test "$VERBOSE" == "1"; then echo $OPENSTACK $1 list $3 -f value $VALS $EXTRA 1>&2; fi
	ANS="$($OPENSTACK $1 list $3 -f value $VALS $EXTRA)"
	if test $? != 0; then echo "ERROR executing $OPENSTACK $1 list $3 -f value $VALS $EXTRA" 1>&2; return 1; fi
	if test -z "$ANS"; then return 0; fi
	if test -n "$2"; then ANS=$(echo "$ANS" | grep "$2"); fi
	if test "$VERBOSE" == "1"; then echo "$ANS" | sed 's/^/  /' 1>&2; fi
	if test "$1" == "keypair"; then echo "$ANS";
	elif test -n "$4"; then echo "$ANS" | sed 's/^\([0-9a-f-]*\) .* \(.*\)$/\1 \2/g';
	else echo "$ANS" | sed 's/^\([0-9a-f-]*\) .*$/\1/g'; fi
	return 0
}

# delete a list of openstack resources
# $1 => resource type
# $2 => optionally filter for field number on resource list
# $3 => optional single step with this arg prefixed
# $4-* => resource list
cleanup_list()
{
	ARG="$1"; shift
	ARGNO="$1"; shift
	SINGLE="$1"; shift
	if test -z "$1"; then return 0; fi
	if test -n "$ARGNO"; then LST=$(echo "$*" | awk "{ print \$$ARGNO; }"); else LST="$*"; fi
	case "$ARG" in
		loadbalancer*)
			WAIT="--wait" ;;
		*)
			WAIT="" ;;
	esac
	if test -n "$SINGLE"; then
		for INST in $LST; do
			echo $OPENSTACK $ARG delete $WAIT $SINGLE $INST 1>&2
			$OPENSTACK $ARG delete $WAIT $SINGLE $INST
		done
	else
		echo $OPENSTACK $ARG delete $WAIT $LST 1>&2
		$OPENSTACK $ARG delete $WAIT $LST
	fi
	let DELETED+=$(echo $LST | wc -w)
}

# collect list of resources, filtering for names
# $1 => type (can be several strings separated by spaces, e.g. "loadbalancer listener")
# $2 => filter (optional)
# $3 => argument (optional)
# return value: 0 success, 1 error
# outputs list of UUIDs, one per line
# if argument $3 is passed, the deletion will happen one per CLI call

# clean resources of type "$1" filter "$2"
cleanup()
{
	RL=$(resourcelist "$1" "$2" "$3")
	RC=$?
	if test $RC != 0; then return $RC; fi
	if test "${3:0:2}" == "--"; then cleanup_list "$1" "" "" "$RL"; else cleanup_list "$1" "" "$3" "$RL"; fi
}

# main
if test "$1" == "--verbose"; then VERBOSE=1; shift; fi
if test "$1" == "--full"; then FULL=1; shift; fi
if test -z "$1"; then CLUSTER="testcluster"; else CLUSTER="$1"; shift; fi
if test -z "$1"; then CAPIPRE="capi"; else CAPIPRE="$1"; shift; fi
CAPIPRE2="k8s-clusterapi-cluster-default"
CAPIPRE3="k8s-cluster-default"

# For full cleanup, delete CAPI mgmt server first
if test "$FULL" == "1"; then
	echo "Deleting management node with prefix $CAPIPRE"
	CAPI=$(resourcelist server ${CAPIPRE}-mgmtcluster "" Networks)
	cleanup_list server 1 "" "$CAPI"
	cleanup_list "floating ip" 2 "" "$CAPI"
fi

echo "Deleting cluster $CLUSTER"
# cleanup loadbalancers
if test -n "$NOCASCADE"; then
POOLS=$(resourcelist "loadbalancer pool" "\(clusterapi-.*-${CLUSTER}-kubeapi\|kube_service_${CLUSTER}_ingress-nginx_ingress-nginx-controller\)")
for POOL in $POOLS; do
	#MEMBERS=$(resourcelist "loadbalancer member" clusterapi $POOL)
	cleanup "loadbalancer member" "\(clusterapi-.*-${CLUSTER}-kubeapi\|kube_service_${CLUSTER}_ingress-nginx_ingress-nginx-controller\)" $POOL
done
cleanup_list "loadbalancer pool" "" "" "$POOLS"
cleanup "loadbalancer listener" "\(clusterapi-.*-${CLUSTER}-kubeapi\|kube_service_${CLUSTER}_ingress-nginx_ingress-nginx-controller\)"
fi
LBS=$(resourcelist loadbalancer "\(clusterapi-.*-${CLUSTER}-kubeapi\|kube_service_${CLUSTER}_ingress-nginx_ingress-nginx-controller\)" "" vip_address)
#cleanup_list "floating ip" 2 "" "$LBS"
while read LB FIP; do
	if test -z "$FIP"; then continue; fi
	if test "$VERBOSE" == "1"; then echo $OPENSTACK floating ip list --fixed-ip-address $FIP -f value -c ID 1>&2; fi
	FID=$($OPENSTACK floating ip list --fixed-ip-address $FIP -f value -c ID)
	if test "$VERBOSE" == "1"; then echo "$FID" | sed 's/^/  /' 1>&2; fi
	if test -n "$FID"; then
		echo $OPENSTACK floating ip delete $FID 1>&2
		$OPENSTACK floating ip delete $FID
	fi
done < <(echo "$LBS")
if test -n "$NOCASCADE"; then
	cleanup_list loadbalancer 1 "" "$LBS"
else
	cleanup_list loadbalancer 1 "--cascade" "$LBS"
fi
cleanup server $CAPIPRE-$CLUSTER
cleanup port $CAPIPRE-$CLUSTER
RTR=$(resourcelist router $CAPIPRE2-$CLUSTER)
SUBNETS=$(resourcelist subnet $CAPIPRE2-$CLUSTER)
if test -n "$RTR" -a -n "$SUBNETS"; then
	echo $OPENSTACK router remove subnet $RTR $SUBNETS 1>&2
	$OPENSTACK router remove subnet $RTR $SUBNETS
fi
cleanup_list subnet "" "" "$SUBNETS"
#cleanup subnet $CAPIPRE2-$CLUSTER
cleanup network $CAPIPRE2-$CLUSTER
#cleanup router $CAPIPRE2-$CLUSTER
cleanup_list router "" "" "$RTR"
cleanup "security group" $CAPIPRE3-$CLUSTER
cleanup "security group" $CAPIPRE-$CLUSTER-cilium
#cleanup "image" ubuntu-capi-image
# The PVC volumes are NOT deleted here
cleanup volume $CAPIPRE-$CLUSTER
cleanup "server group" "$CAPIPRE-$CLUSTER"
cleanup "application credential" "$CAPIPRE-$CLUSTER-appcred"

# Continue with capi control plane
if test "$FULL" == "1"; then
	RTR=$(resourcelist router ${CAPIPRE}-rtr)
	SUBNETS=$(resourcelist subnet ${CAPIPRE}-subnet)
	if test -n "$RTR" -a -n "$SUBNETS"; then
		echo $OPENSTACK router remove subnet $RTR $SUBNETS 1>&2
		$OPENSTACK router remove subnet $RTR $SUBNETS
	fi
	if test -n "$SUBNETS"; then
		cleanup port "" "--fixed-ip subnet=$SUBNETS"
	fi
	#cleanup subnet ${CAPIPRE}-subnet
	cleanup_list subnet "" "" "$SUBNETS"
	cleanup network ${CAPIPRE}-net
	#cleanup router ${CAPIPRE}-
	cleanup_list router "" "" "$RTR"
	cleanup "security group" ${CAPIPRE}-mgmt
	cleanup "security group" allow-
	cleanup keypair ${CAPIPRE}-keypair
	cleanup "application credential" ${CAPIPRE}-appcred
	#cleanup volume pvc-
	echo "Volumes from Cinder CSI left:"
	echo $OPENSTACK volume list 1>&2
	$OPENSTACK volume list | grep 'pvc-'
fi

echo "Deleted $DELETED OpenStack resources"
