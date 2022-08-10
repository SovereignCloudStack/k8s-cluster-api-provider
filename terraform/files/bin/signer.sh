#!/bin/bash
# k8s signer
# (c) Kurt Garloff <garloff@osb-alliance.com>, 8/2022
# SPDX-License-Identifier: CC-BY-SA-4.0
#
# Usage:
# * Create a directory where you put the kubernetes ca.crt and .key.
# * Go into this directory
# * Calling signer.sh CLUSTERNAME will sign all CSRs that have been marked approved
#   with the CA cert and push the cert back into k8s.
# * For Pending requests, it will display and interactively ask, which can be
#   changed using options -f and -a.

usage()
{
	echo "Usage: signer.sh CLUSTERNAME [OPTIONS]"
	echo "Options: -a => only sign approved CSRs"
	echo "         -f => approve and sign all"
	echo "Default is to ask for unapproved"
	exit 1
}


if test -z "$1"; then usage; fi

CTX="--context=$1-admin@$1"
shift
if test "$1" == "-a"; then ONLYAPPROVED=1; shift; fi
if test "$1" == "-f"; then FORCEAPPROVE=1; shift; fi

if test ! -r ca.crt -o ! -r ca.key; then
	echo "Need ca.crt and ca.key in current directory"
	exit 2
fi

if ! type -p jq >/dev/null; then echo "Need jq installed"; exit 2; fi
if ! type -p cfssl >/dev/null; then echo "Need cfssl installed"; exit 2; fi

if test ! -r server-signing-config.json; then cat > server-signing-config.json <<EOT
{
    "signing": {
        "default": {
            "usages": [
                "digital signature",
                "key encipherment",
                "server auth"
            ],
            "expiry": "8784h",
            "ca_constraint": {
                "is_ca": false
            }
        }
    }
}
EOT
fi

sign()
{
	# FIXME: Need to determine API version
	CERTAPI=v1beta1
	REQ=$(kubectl $CTX get csr $1 -o jsonpath='{.spec.request}' | base64 --decode) || exit 4
	OSSLINFO=$(echo "$REQ" | openssl req -noout -text -in -)
	echo "Signing $1: $OSSLINFO"
	echo "$REQ" | cfssl sign -ca ca.crt -ca-key ca.key -config server-signing-config.json - | cfssljson -bare signed-$1
	if test "${PIPESTATUS[1]}" != "0"; then exit 5; fi
	# Append issuer cert to have full trust chain
	cat ca.crt >> signed-$1.pem
	kubectl $CTX get csr $1 -o json | jq '.status.certificate = "'$(base64 signed-$1.pem | tr -d '\n')'"' | \
		kubectl $CTX replace --raw /apis/certificates.k8s.io/$CERTAPI/certificatesigningrequests/$1/status -f - || exit 6
}


while read req age signer requestor status; do
	if test "$status" = "Approved,Issued"; then continue
	elif test "$status" = "Approved"; then sign $req; continue
	elif test "$status" != "Pending"; then continue
	fi
	#FIXME: Should ask openstack whether DNS nama and IP match ....
	if test "$ONLYAPPROVED" = "1"; then continue; fi
	if test "$FORCEAPPROVE" = "1"; then
		echo "Force approval for $req ($requestor -> $signer / $age)"
		kubectl $CTX certificate approve $req
		sign $req
		continue
	fi
	REQ=$(kubectl $CTX get csr $req -o jsonpath='{.spec.request}' | base64 --decode)
	OSSLINFO=$(echo "$REQ" | openssl req -noout -text -in -)
	echo -ne "$OSSLINFO\nApprove $req ($requestor -> $signer / $age)? "
	read ans </dev/tty
	if test "$ans" = "y" -o "$ans" = "Y" -o "$ans" = "1" -o "$ans" = "yes" -o "$ans" = "YES" -o "$ans" = "Yes"; then
		kubectl $CTX certificate approve $req
		sign $req
	fi
done < <(kubectl $CTX get csr)

