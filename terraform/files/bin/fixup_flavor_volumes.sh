#!/bin/bash
#
# fixup_flavor_volumes.sh
#
# Usage: fixup_flavor_volumes.sh CCCFG CLUSTERTEMPLATE
#  Check if the flavor has a disk that's large enough
#  Change machine template to allocate root disk of sufficient size if no disk exists
#
# (c) Kurt Garloff <scs@garloff.de>, 6/2023
# SPDX-License-Identifier: Apache-2.0

usage()
{
	echo "Usage: fixup_flavor_volumes.sh CLUSTERCTL CLUSTERTEMPLATE"
	exit 1
}

if test -z "$2"; then usage; fi

UBU_IMG_NM=$(yq eval '.OPENSTACK_IMAGE_NAME' $1)
CTRLFLAVOR=$(yq eval '.OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR' $1)
WORKFLAVOR=$(yq eval '.OPENSTACK_NODE_MACHINE_FLAVOR' $1)

flavor_disk.sh "$CTRLFLAVOR" "$UBU_IMG_NM"
DISKCTRL=$?
flavor_disk.sh "$WORKFLAVOR" "$UBU_IMG_NM"
DISKWORK=$?

if test $DISKCTRL -ge 128; then echo "ERROR $((DISKCTRL-256)) using flavor $CTRLFLAVOR for image $UBU_IMG_NM"; exit 1; fi
if test $DISKWORK -ge 128; then echo "ERROR $((DISKWORK-256)) using flavor $WORKFLAVOR for image $UBU_IMG_NM"; exit 1; fi
if test $DISKCTRL != 0; then
	echo "NOT YET IMPLEMENTED: Patch cluster-template.yaml with volume $DISKCTRL GB for ctrl plane"
	exit 2
fi
if test $DISKWORK != 0; then
	echo "NOT YET IMPLEMENTED: Patch cluster-template.yaml with volume $DISKWORK GB for worker node"
	exit 2
fi

