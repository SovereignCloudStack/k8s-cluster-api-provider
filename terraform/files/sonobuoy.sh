#!/bin/bash
#
# Run sonobuoy tests
#
# (c) Kurt Garloff <garloff@osb-alliance.com>
# SPDX-License-Identifier: Apache-2.0
#
if ! test -x ./sonobuoy; then
	SONOBUOY_VERSION=0.53.2
	SONOTARBALL=sonobuoy_${SONOBUOY_VERSION}_linux_amd64.tar.gz
	curl -LO https://github.com/vmware-tanzu/sonobuoy/releases/download/v${SONOBUOY_VERSION}/${SONOTARBALL} || exit 1
	tar xvzf ${SONOTARBALL} || exit 2
	chmod +x ./sonobuoy || exit 2
	rm ${SONOTARBALL}
fi
echo "Running sonobuoy conformance tests ..."
export KUBECONFIG=testcluster.yaml
./sonobuoy run || exit 3
while true; do
	sleep 60
	COMPLETE=$(./sonobuoy status)
	echo "$COMPLETE"
	if echo "$COMPLETE" | grep "has completed" >/dev/null 2>&1; then break; fi
done
resfile=$(./sonobuoy retrieve)
REPORT=$(./sonobuoy results $resfile)
echo "$REPORT"
./sonobuoy delete
declare -i fail=0
while read number; do
	let fail+=$number
done < <(echo "$REPORT" | grep Failed | sed 's/Failed: //')
if test $fail != 0; then exit 4+$fail; fi
echo "Sonobuoy conformance tests passed"
