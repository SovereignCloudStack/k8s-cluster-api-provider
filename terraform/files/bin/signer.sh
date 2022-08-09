#!/bin/bash
# k8s signer
# (c) Kurt Garloff <garloff@osb-alliance.com>, 8/2022
# SPDX-License-Identifier: CC-BY-SA-4.0

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
	CERTAPI=v1beta1
	REQ=$(kubectl $CTX get csr $1 -o jsonpath='{.spec.request}' | base64 --decode)
	OSSLINFO=$(echo "$REQ" | openssl req -noout -text -in -)
	echo "Signing $1: $OSSLINFO"
	SIGNED=$(echo "$REQ" | cfssl sign -ca ca.crt -ca-key ca.key -config server-signing-config.json - | cfssljson -bare signed-$1)
	kubectl $CTX get csr $1 -o json | jq '.status.certificate = "'$(base64 signed-$1.pem | tr -d '\n')'"' | \
		kubectl $CTX replace --raw /apis/certificates.k8s.io/$CERTAPI/certificatesigningrequests/$1/status -f -
}


while read req age signer requestor status; do
	if test "$status" = "Approved,Issued"; then continue
	elif test "$status" = "Approved"; then sign $req
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

