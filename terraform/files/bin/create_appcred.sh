#!/bin/bash
#Determine whether we need a new application credential
unset APPCRED_ID APPCRED_PRJ
APPCREDS=$(openstack application credential list -f value -c ID -c Name -c "Project ID")
while read id nm prjid; do
	#echo "\"$nm\" \"$prjid\" \"$id\""
	if test "$nm" = "$PREFIX-$CLUSTER_NAME-appcred"; then
		echo "Reuse AppCred $nm $id"
		APPCRED_ID=$id
		APPCRED_PRJ=$prjid
	fi
done < <(echo "$APPCREDS")
# Generate a new application credential
if test -z "$APPCRED_ID"; then
	NEWCRED=$(openstack application credential create "$PREFIX-$CLUSTER_NAME-appcred" --description "App Cred $PREFIX for cluster $CLUSTER_NAME" -f value -c id -c project_id -c secret)
	if test $? != 0; then
		echo "Application Credential generation failed." 1>&2
		exit 1
	fi
	read APPCRED_ID APPCRED_PRJ APPCRED_SECRET < <(echo $NEWCRED)
	# Replace secret
	print-cloud.py -c $PREFIX-$CLUSTER_NAME -r application_credential_id=$APPCRED_ID -r application_credential_secret="$APPCRED_SECRET" -i auth_type="#project_id=$APPCRED_PRJ" | grep -v '^#' | grep -v '^---' | grep -v '^clouds:' >> ~/.config/openstack/clouds.yaml
	# And remove from env
	unset APPCRED_SECRET
fi
export OS_CLOUD=$PREFIX-$CLUSTER_NAME
export PROJECTID=$APPCRED_PRJ
# Generate clouds.yaml and cloud.conf and create b64 encoded pieces for clusterctl.yaml
clusterctl_template.sh $CLUSTER_NAME

