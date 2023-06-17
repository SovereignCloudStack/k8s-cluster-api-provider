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

if test $DISKCTRL -ge 128; then echo "ERROR $((DISKCTRL-256)) using ctrlplane flavor $CTRLFLAVOR for image $UBU_IMG_NM"; exit 1; fi
if test $DISKWORK -ge 128; then echo "ERROR $((DISKWORK-256)) using worker flavor $WORKFLAVOR for image $UBU_IMG_NM"; exit 1; fi
if test $DISKCTRL != 0; then
	if grep 'CONTROL_PLANE_ROOT_DISKSIZE' $1 >/dev/null 2>&1; then
		if ! grep '^CONTROL_PLANE_ROOT_DISKIZE' $1 >/dev/null 2>&1; then
			sed -i 's/^.*\(CONTROL_PLANE_ROOT_DISKSIZE\)/\1/' $1
		fi
		if grep '^CONTROL_PLANE_ROOT_DISKIZE: 0 *$' $1 >/dev/null 2>&1; then
			sed -i "s/^\(CONTROL_PLANE_ROOT_DISKIZE: \)0/\1$DISKCTRL/" $1
		fi
	else
		echo -e "# Volume for control plane disk\nCONTROL_PLANE_ROOT_DISKSIZE: $DISKCTRL" >> $1
	fi
	cp -p $2 $2.orig
	kustpatch.sh ~/kubernetes-manifests.d/add-vol-to-ctrl.yaml <$2.orig >$2
else
	sed -i 's/^\(CONTROL_PLANE_ROOT_DISKSIZE\)/#\1/' $1
	cp -p $2 $2.orig
	kustpatch.sh ~/kubernetes-manifests.d/rmv-vol-from-ctrl.yaml <$2.orig >$2
fi
if test $DISKWORK != 0; then
	if grep 'WORKER_ROOT_DISKSIZE' $1 >/dev/null 2>&1; then
		if ! grep '^WORKER_ROOT_DISKIZE' $1 >/dev/null 2>&1; then
			sed -i 's/^.*\(WORKER_ROOT_DISKSIZE\)/\1/' $1
		fi
		if grep '^WORKER_ROOT_DISKIZE: 0 *$' $1 >/dev/null 2>&1; then
			sed -i "s/^\(WORKER_ROOT_DISKIZE: \)0/\1$DISKWORK/" $1
		fi
	else
		echo -e "# Volume for worker node disk\nWORKER_ROOT_DISKSIZE: $DISKWORK" >> $1
	fi
	cp -p $2 $2.orig
	kustpatch.sh ~/kubernetes-manifests.d/add-vol-to-worker.yaml <$2.orig >$2
else
	sed -i 's/^\(WORKER_ROOT_DISKSIZE\)/#\1/' $1
	cp -p $2 $2.orig
	kustpatch.sh ~/kubernetes-manifests.d/rmv-vol-from-worker.yaml <$2.orig >$2
fi
