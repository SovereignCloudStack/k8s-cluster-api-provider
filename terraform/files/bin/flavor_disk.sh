#!/bin/bash
#
# flavor_disk.sh
#
# Determine if flavor needs a volume and return needed size
# Usage: flavor_disk.sh FLAVOR [IMAGE]
#  Determines whether FLAVOR has a disk
#  If yes, return 0 (no disk needed)
#  If no, return a number (size of disk to be created),
#    The size is calculatd by heuristic: 20+RAM/2 rounded to next 5, max 125
#  If FLAVOR does not exit: return -1
#  If IMAGE is passed in addition:
#   If FLAVOR has large enough disk: return 0
#   If FLAVOR disk is too small: return -2
#   If FLAVOR has no disk: calculate ImgSize+RAM/2 rounded to 5, max 125
#   If FLAVOR does not exist: -1
#   If IMAGE does not exist: -3
#
# Requirements: OS_CLOUD needs to be set to a working cloud, openstack CLI
#  needs to be installed and work and cloud API needs to respond.
#
# This is used to determine if we need to add disks to capo machine templates.
#
# (c) Kurt Garloff <scs@garloff.de>, 6/2023
# SPDX-License-Identifier: Apache-2.0

usage()
{
	echo "Usage: flavor_disk.sh FLAVOR [IMAGE]"
	exit 1
}

if test -z "$1"; then usage; fi
if ! command -v jq &>/dev/null; then
  sudo apt-get update && sudo apt-get install -y jq
fi

FLAVOR=`openstack flavor show $1 -f json`
if test $? != 0; then exit -1; fi
if test -n "$2"; then
	IMAGE=`openstack image show $2 -f json`
	if test $? != 0; then exit -3; fi
	ISIZE=`echo "$IMAGE" | jq '.min_disk'`
else
	ISIZE=20
fi
CPU=`echo "$FLAVOR" | jq '.vcpus'` #  | tr -d '"'
RAM=`echo "$FLAVOR" | jq '.ram'`
RAM=$(((RAM+64)/1024))
DISK=`echo "$FLAVOR" | jq '.disk'`
#FIXME: Should we prevent single CPU here?
if test $DISK != 0; then
	if test $DISK -lt $ISIZE; then exit -2; else exit 0; fi
else
	WANT=$(((ISIZE+2+$RAM/2)/5*5))
	if test $WANT -gt 125; then WANT=125; fi
	if test $WANT -lt $ISIZE; then WANT=$ISIZE; fi
	exit $WANT
fi
