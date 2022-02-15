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
export KUBECONFIG=testcluster.yaml
if ! test -s "$KUBECONFIG"; then echo "No $KUBECONFIG" 1>&2; exit 3; fi
#./sonobuoy status 2>/dev/null
#./sonobuoy delete --wait
START=$(date +%s)
echo "=== Running sonobuoy conformance tests ... $@ ==="
sonobuoy run --plugin-env=e2e.E2E_PROVIDER=openstack "$@" || exit 4
if test "$1" == "--mode" -a "$2" == "quick"; then SLP=10; ALL=""; else SLP=60; ALL="--all"; fi
while true; do
	sleep $SLP
	COMPLETE=$(sonobuoy status)
	date +%FT%TZ
	echo "$COMPLETE"
	#sonobuoy logs -f
	if echo "$COMPLETE" | grep "has completed" >/dev/null 2>&1; then break; fi
	#./sonobuoy logs
done
echo "=== Collecting results ==="
resfile=$(sonobuoy retrieve)
sonobuoy delete $ALL
REPORT=$(sonobuoy results $resfile)
echo "$REPORT"
END=$(date +%s)
declare -i fail=0
while read number; do
	let fail+=$number
done < <(echo "$REPORT" | grep 'Failed: ' | sed 's/Failed: //')
sonobuoy delete $ALL --wait
if test $fail != 0; then
	echo "FAIL: Investigate $resfile for further inspection" 1>&2
	exit $((4+$fail))
fi
rm $resfile
echo "=== Sonobuoy conformance tests passed in $((END-START))s ==="
