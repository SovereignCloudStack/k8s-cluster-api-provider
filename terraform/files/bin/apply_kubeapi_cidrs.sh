#!/bin/bash
# apply_kubeapi_cidrs.sh
# Patch $2 (${CLUSTER_NAME}-config.yaml) to enforce API access restrictions (if enabled)
# Reference: https://cluster-api-openstack.sigs.k8s.io/clusteropenstack/configuration.html#restrict-access-to-the-api-server
# (c) Kurt Garloff, 03/2023
# SPDX-License-Identifier: Apache-2.0
. /etc/profile.d/proxy.sh
# Test if passed list is empty
empty_list()
{
	if test -z "$1" -o "$1" = "null"; then return 0; fi
	if test "$1" = "[]" -o "$1" = "[ ]" -o "$1" = "[  ]"; then return 0; fi
	return 1
}

get_own_fip()
{
	NETS=$(openstack server list --name "${PREFIX}-mgmtcluster" -f value -c Networks)
	#FIP=${NETS##*, }
	FIP=$(echo "$NETS" | sed "s/^.*, [']\{0,1\}\(\([0-9]*\.\)\{3\}[0-9]*\).*\$/\1/g")
}

# Add access restrictions
# Input is a list in brackets.
# Ignore none, always add own FIP
kustomize_cluster_cidrs()
{
	KPATCH=~/${CLUSTER_NAME}/restrict-kubeapi-cidr.yaml
	cat >$KPATCH <<EOT
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
kind: OpenStackClusterTemplate
metadata:
  name: ${CLUSTER_NAME}
spec:
  template:
    spec:
      allowAllInClusterTraffic: true
      apiServerLoadBalancer:
        allowedCidrs:
        - $FIP/32
EOT
	for item in $1; do
		#echo "$item"
		item=${item%,}
		if test "$item" = "[" -o $item = "]" -o -z "$item"; then continue; fi
		if test "$item" = "none"; then continue; fi
		if test "${item%/*}" = "$item"; then item="$item/32"; fi
		echo "        - $item" >> $KPATCH
	done
	cp -p "$2" "$2.orig"
	#cat $KPATCH
	kustpatch.sh $KPATCH <"$2.orig" >"$2"
        RC=$?
	if test $RC != 0; then cp -p "$2.orig" "$2"; fi
	return $RC
}

if test -z "$2"; then echo "ERROR: Need clusterctl.yaml cluster-template args" 1>&2; exit 1; fi
RESTRICT_KUBEAPI=$(yq eval .RESTRICT_KUBEAPI $1)
if empty_list "$RESTRICT_KUBEAPI"; then exit 0; fi
get_own_fip
kustomize_cluster_cidrs "$RESTRICT_KUBEAPI" "$2"
