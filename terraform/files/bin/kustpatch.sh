#!/bin/bash
# kustpatch.sh
# 
# I see kustomize as an intelligent (format-aware) way to apply
# patches to yaml. The usage is cumbersome however, as it requires
# to setup directories with kustomization files etc.
# This can be simplified a lot.
# 
# Apply a set of kustomizations (passed on the command line) to
# yaml file provided via stdin; result is output to stdout
# 
# This takes care of setting up the directory structure that kustomize
# expects.
#
# Usage: 
# kustpatch.sh kust1.yaml [kust2.yaml [...]] < base.yaml > result.yaml
#
# (c) Kurt Garloff <garloff@osb-alliance.com>, 3/2022
# SPDX-License-Identifier: CC-BY-SA-4.0

unset KTMPDIR
cleanup()
{
	# Set KEEPKUST for debugging
	if test -n "$KTMPDIR" -a -d "$KTMPDIR" -a -z "$KEEPKUST"; then
		cd; rm -rf "$KTMPDIR"
	fi
}

usage()
{
	echo "Usage: kustpatch.sh kust1.yaml [kust2.yaml [...]] < base.yaml > result.yaml" 1>&2
	cleanup
	exit ${1:-1}
}

if test -z "$1"; then usage; fi

# stupid snap
#TMPDIR=$(mktemp -d /dev/shm/kustpatch.XXXXXX) || exit 2
if test ! -d ~/tmp; then mkdir ~/tmp; fi
IWD=$(pwd)
KTMPDIR=$(mktemp -d ~/tmp/kustpatch.XXXXXX) || exit 2

mkdir $KTMPDIR/base || exit 2
mkdir $KTMPDIR/patch
cd $KTMPDIR/base; kustomize create || exit 3
cd ..; cp -p base/kustomization.yaml patch/
cd $IWD

if test ! -t 0; then cat > $KTMPDIR/base/base.yaml; fi
if test ! -s $KTMPDIR/base/base.yaml; then
	INPUT=$(grep '^#YAML_TO_PATCH:' "$@" | sed 's/^.*#YAML_TO_PATCH: *//g' | head -n1)
	if test -z "$INPUT"; then echo "ERROR: Pass input YAML via stdin (or specify in patch header)" 1>&2; usage 4; fi
	if test "${INPUT:0:4}" = "http"; then
		curl -fsSL "$INPUT" -o $KTMPDIR/base/base.yaml
		RC=$?
		if test $RC != 0; then echo "ERROR: Could not retrieve $INPUT" 1>&2; usage 4; fi
	else
		if test ! -s "$INPUT"; then echo "ERROR: Base file $INPUT not readable" 1>&2; usage 4; fi
		cp -p "$INPUT" $KTMPDIR/base/base.yaml
	fi
fi
echo -e "resources:\n  - base.yaml" >> $KTMPDIR/base/kustomization.yaml
echo -e "bases:\n - ../base\npatches:" >> $KTMPDIR/patch/kustomization.yaml

for patch in "$@"; do
       if test ! -s "$patch"; then echo "ERROR: Patch file $patch not readable" 1>&2; usage 5; fi
       cp -p "$patch" $KTMPDIR/patch/
       echo " - ${patch##*/}" >> $KTMPDIR/patch/kustomization.yaml
done
cd $KTMPDIR
kustomize build patch
RC=$?
cleanup
exit $RC

