#!/bin/bash
#
# Run sonobuoy tests
#
# (c) Kurt Garloff <garloff@osb-alliance.com>
# SPDX-License-Identifier: Apache-2.0
#
unset TZ
export LC_ALL=POSIX
if ! test -x /usr/local/bin/sonobuoy; then
	SONOBUOY_VERSION=0.53.2
	SONOTARBALL=sonobuoy_${SONOBUOY_VERSION}_linux_amd64.tar.gz
	curl -LO https://github.com/vmware-tanzu/sonobuoy/releases/download/v${SONOBUOY_VERSION}/${SONOTARBALL} || exit 1
	tar xvzf ${SONOTARBALL} || exit 2
	chmod +x ./sonobuoy || exit 2
	sudo mv sonobuoy /usr/local/bin/
	rm ${SONOTARBALL}
fi
echo "=== Running sonobuoy conformance tests ... $@ ==="
export KUBECONFIG=testcluster.yaml
if ! test -r "$KUBECONFIG"; then echo "No $KUBECONFIG" 1>&2; exit 3; fi
sonobuoy run "$@" || exit 4
if test "$1" == "--mode" -a "$2" == "quick"; then SLP=10; ALL=""; else SLP=60; ALL="--all"; fi
while true; do
	sleep $SLP
	COMPLETE=$(sonobuoy status)
	date +%FT%TZ
	echo "$COMPLETE"
	#sonobuoy logs -f
	if echo "$COMPLETE" | grep "has completed" >/dev/null 2>&1; then break; fi
done
echo "=== Collecting results ==="
resfile=$(sonobuoy retrieve)
REPORT=$(sonobuoy results $resfile)
echo "$REPORT"
sonobuoy delete $ALL
declare -i fail=0
while read number; do
	let fail+=$number
done < <(echo "$REPORT" | grep 'Failed: ' | sed 's/Failed: //')
if test $fail != 0; then exit $((4+$fail)); fi
echo "=== Sonobuoy conformance tests passed ==="
