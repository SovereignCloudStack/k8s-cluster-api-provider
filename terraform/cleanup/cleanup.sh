#!/bin/bash
#
# Cleanup script for SCS k8s-cluster-api-provider
#
# Unlike ospurge, this only cleans up what comes from the provider
#
# (c) Kurt Garloff <garloff@osb-alliance.com>, 8/2021
# SPDX-License-Identifier: Apache-2.0
#
# Usage: cleanup.sh [--debug] [--verbose] [--full]
#                   [--force-fip] [--force-pvc] [PREFIX [[CLUSTERNAMES]]
# Note: The order of options args is fixed due to naive parser

if test -z "$OPENSTACK"; then OPENSTACK="openstack"; fi

declare -i DELETED=0

if test "$1" == "--debug"; then DEBUG=1; shift; fi
if test -n "$DEBUG"; then echo "# INFO: DEBUG set, won't delete anything for real"; DBG="Would have "; fi

# collect list of resources, filtering for names
# $1 => type (can be several strings separated by spaces, e.g. "loadbalancer listener")
# $2 => filter (optional)
# $3 => argument (optional)
# $4 => additional argument to return (optional)
# $5 => custom `sed` expression to use (optional)
# return value: 0 success, 1 error
# outputs list of UUIDs, one per line
# if $4 is passed, extra results are returned in second field per line
# if $5 is passed, a custom `sed` expression is used

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
	elif test -n "$5"; then echo "$ANS" | sed "$5";
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
			if test -z "$DEBUG"; then $OPENSTACK $ARG delete $WAIT $SINGLE $INST; fi
		done
	else
		echo $OPENSTACK $ARG delete $WAIT $LST 1>&2
		if test -z "$DEBUG"; then $OPENSTACK $ARG delete $WAIT $LST; fi
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

# Find volumes attached to a set of servers
# $* => list of server UUIDs
# Output a list of volume UUIDs that are attached
server_vols()
{
	if test -z "$1"; then echo; return 1; fi
	srchexpr="\\("
	for arg in "$@"; do
		srchexpr="$srchexpr$arg\\|"
	done
	srchexpr="${srchexpr%\\|}\\)"
	#if test -n "$DEBUG"; then echo "#### Search for volumes $srchexpr"; fi
	ANS=$($OPENSTACK volume list -f value -c ID -c "Attached to" | grep "'server_id': '$srchexpr'" | cut -f1 -d " ")
	echo $ANS
	return 0
}


# main
# TODO: Real option parser with help
if test "$1" == "--verbose"; then VERBOSE=1; shift; fi
if test "$1" == "--full"; then FULL=1; MGMTSRV=" management server and"; shift; fi
if test "$1" == "--force-fip"; then FORCEFIP=1; shift; fi
if test "$1" == "--force-pvc"; then FORCEPVC=1; shift; fi
#if test -z "$1"; then CAPIPRE="${CAPIPRE:-capi}"; else CAPIPRE="$1"; shift; fi
#if test -z "$1"; then CLUSTERS="${CLUSTER:-testcluster}"; else CLUSTERS="$1"; shift; fi
if test -n "$1"; then CAPIPRE="$1"; shift; fi
if test -n "$1"; then CLUSTERS="$@"; shift; fi
# Try to guess CAPIPRE if it's unset
if test -z "$CAPIPRE"; then
	ENVIRONMENT=${ENVIRONMENT:-$OS_CLOUD}
	ENVFILE=environments/environment-$ENVIRONMENT.tfvars
	if test -n "$ENVIRONMENT" -a -r $ENVFILE && grep '^prefix[ =]' $ENVFILE >/dev/null 2>&1; then
		CAPIPRE="$(grep '^prefix[ =]' $ENVFILE | sed 's/^prefix *= *//' | tr -d '"')"
	else
		CAPIPRE=capi
	fi
fi
echo "# Deleting$MGMTSRV clusters for $CAPIPRE"
# Try to detect cluster(s)
if test -z "$CLUSTERS"; then
	# Look for application credentials ... these tend to be created first
	while read id name; do
		nm=${name%-appcred}
		nm=${nm#$CAPIPRE-}
		CLUSTERS="$nm $CLUSTERS"
	done < <($OPENSTACK application credential list -f value -c ID -c Name | grep $CAPIPRE-[^-]*-appcred)

fi
# Still no cluster?
if test -z "$CLUSTERS"; then
	ENVIRONMENT=${ENVIRONMENT:-$OS_CLOUD}
	ENVFILE=environments/environment-$ENVIRONMENT.tfvars
	if test -n "$ENVIRONMENT" -a -r $ENVFILE && grep '^testcluster_name[ =]' $ENVFILE >/dev/null 2>&1; then
		CLUSTERS="$(grep '^testcluster_name[ =]' $ENVFILE | sed 's/^testcluster_name *= *//' | tr -d '"')"
	else
		CLUSTERS=testcluster
	fi
fi

# For full cleanup, delete CAPI mgmt server first
if test "$FULL" == "1"; then
	echo "## Deleting management node with prefix $CAPIPRE"
	# Note: Column "Networks" contains a map of server's network names and associated IPs.
	#  OpenStack client =<5.4.0 returns network details as follows:
	#    <network-name-1>=<IP>, <IP>, ..., <network-name-n>=<IP>, <IP>
	#  OpenStack client =>5.5.0 returns network details as follows:
	#    {'<network-name-1>': ['<IP>', '<IP>'], ..., '<network-name-n>': ['<IP>', '<IP>']}
	#  Custom `sed` expression below filters the last IP from the last server network. It works with both formats.
	#  We assumed here that it is a floating IP associated with the capi mgmt server.
	CAPI=$(resourcelist server ${CAPIPRE}-mgmtcluster "" Networks "s/^\([0-9a-f-]*\) .*, [']\{0,1\}\(\([0-9]*\.\)\{3\}[0-9]*\).*\$/\1 \2/g")
	CAPIVOL=$(server_vols ${CAPI%% *})
	if test -n "$DEBUG"; then echo "## Attached volumes to ${CAPI%% *}: $CAPIVOL"; fi
	cleanup_list server 1 "" "$CAPI"
	cleanup_list "floating ip" 2 "" "$CAPI"
fi

echo "## Deleting clusters $CLUSTERS"

for CLUSTER in $CLUSTERS; do

CAPIPRE2X="k8s\-clusterapi\-cluster"
CAPIPRE2ALL="k8s\-clusterapi\-cluster\-\(default\|$CLUSTER\)\-$CLUSTER"
CAPIPRE3X="k8s\-cluster"
CAPIPRE3ALL="k8s\-cluster\-\(default\|$CLUSTER\)\-$CLUSTER"

echo "### Deleting cluster $CLUSTER"
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
		if test -z "$DEBUG"; then $OPENSTACK floating ip delete $FID; fi
	fi
done < <(echo "$LBS")
SRV=$(resourcelist server $CAPIPRE-$CLUSTER)
SRVVOL=$(server_vols $SRV)
if test -n "$DEBUG"; then echo "### Attached volumes to "${SRV}": $SRVVOL"; fi
#cleanup server $CAPIPRE-$CLUSTER
cleanup_list server "" "" "$SRV"
if test -n "$NOCASCADE"; then
	cleanup_list loadbalancer 1 "" "$LBS"
else
	cleanup_list loadbalancer 1 "--cascade" "$LBS"
fi
cleanup port $CAPIPRE-$CLUSTER
RTR=$(resourcelist router "$CAPIPRE2ALL")
SUBNETS=$(resourcelist subnet "$CAPIPRE2ALL")
if test -n "$RTR" -a -n "$SUBNETS"; then
	echo $OPENSTACK router remove subnet $RTR $SUBNETS 1>&2
	if test -z "$DEBUG"; then $OPENSTACK router remove subnet $RTR $SUBNETS; fi
fi
cleanup_list subnet "" "" "$SUBNETS"
#cleanup subnet $CAPIPRE2ALL
cleanup network "$CAPIPRE2ALL"
#cleanup router $CAPIPRE2-$CLUSTER
cleanup_list router "" "" "$RTR"
cleanup "security group" "$CAPIPRE3ALL"
cleanup "security group" $CAPIPRE-$CLUSTER-cilium
NGINX_SG=$($OPENSTACK security group list -f value -c ID -c Name -c Description | grep ' lb-sg' | grep " in cluster $CLUSTER\$")
if test -n "$NGINX_SG"; then
	NGINX_SGS=$(echo "$NGINX_SG" | sed 's/ .*$//g')
	echo "$OPENSTACK security group delete $NGINX_SGS" 1>&2
	if test -z "$DEBUG"; then $OPENSTACK security group delete $NGINX_SGS; fi
fi
# This should hit all volumes that were attached to the servers
echo "### Hint: It's safe to ignore errors on already deleted volumes here"
cleanup_list volume "" "" "$SRVVOL"
#cleanup "image" ubuntu-capi-image
cleanup "server group" "$CAPIPRE-$CLUSTER"
# Normally, the volumes should be all gone, but if there's one left, take care of it
cleanup volume $CAPIPRE-$CLUSTER
cleanup "application credential" "$CAPIPRE-$CLUSTER-appcred"

done

# Continue with capi control plane
if test "$FULL" == "1"; then
	echo "## Cleanup management server"
	RTR=$(resourcelist router ${CAPIPRE}-rtr)
	SUBNETS=$(resourcelist subnet ${CAPIPRE}-subnet)
	FIP=$($OPENSTACK floating ip list -f value -c ID --tags "$CAPIPRE-mgmtcluster")
	cleanup_list "floating ip" "" "" "$FIP"
	if test -n "$RTR" -a -n "$SUBNETS"; then
		echo $OPENSTACK router remove subnet $RTR $SUBNETS 1>&2
		if test -z "$DEBUG"; then $OPENSTACK router remove subnet $RTR $SUBNETS; fi
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
	cleanup "security group" ${CAPIPRE}-allow-
	cleanup keypair ${CAPIPRE}-keypair
	echo "## Hint: It's safe to ignore errors on an already deleted volume here"
	cleanup_list volume "" "" "$CAPIVOL"
	cleanup "application credential" ${CAPIPRE}-appcred
	cleanup volume $CAPIPRE-mgmthost
fi
if test -n "$FORCEPVC"; then
	cleanup volume pvc-
else
	echo "## INFO: Volumes left, possibly from Cinder CSI:"
	echo $OPENSTACK volume list 1>&2
	$OPENSTACK volume list | grep 'pvc-'
fi
if test -n "$FORCEFIP"; then
	FIP=$($OPENSTACK floating ip list --status DOWN -f value -c ID)
	cleanup_list "floating ip" "" "" "$FIP"
fi

echo "# ${DBG}deleted $DELETED OpenStack resources"
