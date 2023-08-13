#!/bin/bash
# create_appcred.sh
# Determine whether we need to create a per-cluster application credential
# and add an appropriate config to the clouds.yaml section.
# Call clusterctl_template.sh to update clusterctl.yaml
# 
# (c) Kurt Garloff <garloff@osb-alliance.com>, 7/2022
# SPDX-License-Identifier: Apache-2.0
# 
#Determine whether we need a new application credential
export KUBECONFIG=$HOME/.kube/config
~/bin/mng_cluster_ns.inc
# If the cluster exists already and we don't have a private appcred, leave it alone
if kubectl get cluster $CLUSTER_NAME >/dev/null 2>&1 && ! grep '^OLD_OPENSTACK_CLOUD' ~/$CLUSTER_NAME/clusterctl.yaml >/dev/null 2>&1; then
	echo "#Warn: Old style cluster, disable new appcred handling"
	exit 0
fi
if kubectl get cluster $CLUSTER_NAME --namespace default >/dev/null 2>&1 && ! grep '^OLD_OPENSTACK_CLOUD' ~/$CLUSTER_NAME/clusterctl.yaml >/dev/null 2>&1; then
	echo "#Warn: Old style cluster, disable new appcred handling"
	exit 0
fi
APPCREDS=$(openstack application credential list -f value -c ID -c Name -c "Project ID")
while read id nm prjid; do
	#echo "\"$nm\" \"$prjid\" \"$id\""
	if test "$nm" = "$PREFIX-$CLUSTER_NAME-appcred"; then
		echo "#Reuse AppCred $nm $id"
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
	echo "#Created AppCred $APPCRED_ID"
	if test ! -e ~/.config/openstack/clouds.yaml.orig; then cp -p ~/.config/openstack/clouds.yaml ~/.config/openstack/clouds.yaml.orig; fi
	#print-cloud.py -c $PREFIX-$CLUSTER_NAME -r application_credential_id=$APPCRED_ID -r application_credential_secret="\"$APPCRED_SECRET\"" -i auth_url="#project_id: $APPCRED_PRJ" | grep -v '^#' | grep -v '^---' | grep -v '^clouds:' >> ~/.config/openstack/clouds.yaml
	# Generate a fresh section rather than relying on cleanliness of existing setup
	AUTH_URL=$(print-cloud.py | yq eval .clouds.${OS_CLOUD}.auth.auth_url -)
	REGION=$(print-cloud.py | yq eval .clouds.${OS_CLOUD}.region_name -)
	CACERT=$(print-cloud.py | yq eval '.clouds."'"$OS_CLOUD"'".cacert // "null"' -)
	# In theory we could also make interface and id_api_vers variable,
	# but let's do that once we find the necessity. Error handling makes
	# it slightly complex, so it's not an obvious win.
	cat >> ~/.config/openstack/clouds.yaml <<EOT
  $PREFIX-$CLUSTER_NAME:
    interface: public
    identity_api_version: 3
    region_name: $REGION
    auth_type: "v3applicationcredential"
    cacert: $CACERT
    auth:
      auth_url: $AUTH_URL
      #project_id: $APPCRED_PRJ
      application_credential_id: $APPCRED_ID
      application_credential_secret: "$APPCRED_SECRET"
EOT
	# And remove secret from env
	unset APPCRED_SECRET NEWCRED
else
	if ! grep "^  $PREFIX-$CLUSTER_NAME:" ~/.config/openstack/clouds.yaml >/dev/null 2>&1; then
		echo "ERROR: Application credential $PREFIX-$CLUSTER_NAME-appcred exists but unknown to us. Please clean up."
		exit 1
	fi
fi
export OS_CLOUD=$PREFIX-$CLUSTER_NAME
export PROJECTID=$APPCRED_PRJ
# Generate clouds.yaml and cloud.conf and create b64 encoded pieces for clusterctl.yaml
clusterctl_template.sh $CLUSTER_NAME

