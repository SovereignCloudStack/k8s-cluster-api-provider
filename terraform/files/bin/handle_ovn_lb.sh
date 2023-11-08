#!/bin/bash
# handle_ovn_lb.sh
# Check USE_OVN_LB_PROVIDER setting and react accordingly:
# * false: do nothingspecial
# * auto: determine if ovn provider LB is available and act like false or true
# * true: set provider to ovn and enable health-monitor
#
# (c) Kurt Garloff <scs@garloff.de>, 02/2023
# SPDX-License-Identifier: Apache-2.0

# imports
. ~/bin/utils.inc
. ~/bin/cccfg.inc

test_ovn_avail()
{
	PROVIDERS=$(openstack loadbalancer provider list -f value -c name)
	if echo "$PROVIDERS" | grep "^ovn$" >/dev/null 2>&1; then return 0; fi
	return 1
}

set_cfg_octavia()
{
	unset VALUE
	while read line; do
		if test "${line:0:1}" = "["; then
			SECTION="${line#[}"
			SECTION="${SECTION%%]*}"
		fi
		if test "$SECTION" = "LoadBalancer" -a "${line:0:${#1}}" = "$1"; then
			VALUE="${line#*=}"
			#echo "Found $1=$VALUE"
		fi
	done < $CLOUDCONF
	if test -n "$VALUE"; then
		if test "$VALUE" = "$2"; then return 0; fi	# Nothing to be done
		#echo "Replace $1=$2"
		sed -i "s@^$1=.*\$@$1=$2@" $CLOUDCONF
		return 1
	else
		#echo "Insert $1=$2"
		sed -i "/^\[LoadBalancer\]/a\
$1=$2" $CLOUDCONF
		return 2
	fi
}

use_ovn()
{
	echo "Warning: use_ovn_lb_provider is a preview feature that does not fully work" 1>&2
	if test "$ALLOW_PREVIEW_FEATURES" != "1"; then echo
		echo "You need to pass --allow-preview-features to allow using it" 1>&2
		exit 1
	fi
	CLOUDCONF="$HOME/$CLUSTER_NAME/cloud.conf"
	set_cfg_octavia "lb-provider" "ovn"
	set_cfg_octavia "lb-method" "SOURCE_IP_PORT"
	set_cfg_octavia "create-monitor" "true"
}

disable_ovn()
{
	CLOUDCONF="$HOME/$CLUSTER_NAME/cloud.conf"
	#sed -i "s/^\(lb-provider=ovn\)/#\1/g" $CLOUDCONF
	sed -i '/lb\-provider=ovn/d' $CLOUDCONF
	sed -i '/lb\-method=SOURCE_IP_PORT/d' $CLOUDCONF
	#sed -i '/create\-monitor=true/d' $CLOUDCONF
}

export USE_OVN=$(yq eval '.USE_OVN_LB_PROVIDER' $CCCFG)
if test "$USE_OVN" = "false"; then disable_ovn
elif test "$USE_OVN" = "auto"; then if test_ovn_avail; then use_ovn; else disable_ovn; fi
elif test "$USE_OVN" = "true"; then use_ovn
else echo "ERROR: Invalid setting for USE_OVN_LB_PROVIDER \"$USE_OVN\"" 1>&2; fi

