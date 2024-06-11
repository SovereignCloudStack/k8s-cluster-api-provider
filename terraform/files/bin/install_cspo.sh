#!/bin/bash
#
# Bootstrap Cluster Stacks on a KaaS v1 management host
#
# Usage: install_cspo.sh [csponame [clusterns]]
# Defaults to cspo and cluster
#
# Needs OS_CLOUD to be set to your target cloud project
#
# (c) Kurt Garloff <garloff@osb-alliance.com>, 3/2024
# SPDX-License-Identifier: ASL-2.0
NAME=${1:-cspo}
CLUSTER=${2:-cluster}
cd
. ~/.capi-settings
if test -e ~/.bash_aliases; then . ~/.bash_aliases; fi
# Check out repos
test_or_update()
{
	if test -d $1; then
		cd $1
		git pull
		cd
	else
		git clone https://github.com/SovereignCloudStack/$1
	fi
}	
test_or_update cluster-stacks
test_or_update cluster-stack-operator
test_or_update cluster-stack-provider-openstack
# envsubst helper (please always call with full path, as there is a name conflict)
ENVSUBST=/usr/local/bin/envsubst
if test ! -x $ENVSUBST; then
	sudo apt-get -y install golang-go
	mkdir -p ~/tmp
	GOBIN=~/tmp go install github.com/drone/envsubst/v2/cmd/envsubst@latest
	sudo mv ~/tmp/envsubst $ENVSUBST
fi
# Deploy CSO and CSPO
if test -z "$GIT_PROVIDER_B64"; then
	echo "Please add GIT_[PROVIDER|ORG_NAME_REPOSITORY_NAME|ACCESS_TOKEN]_B64 to ~/.bash_aliases, see bootstrap.sh" 1>&2
	exit 1
fi
if test -z "$GIT_ACCESS_TOKEN_B64"; then
	echo "Please set GIT_ACCESS_TOKEN_B64 in your ~/.bash_aliases" 1>&2
	exit 1
fi
# CSO manifests
EXTID=$(openstack network list --external -f value -c ID | head -n1)
mkdir -p $NAME
cd $NAME
CSO_VERSION=$(curl https://api.github.com/repos/SovereignCloudStack/cluster-stack-operator/releases/latest -s | jq .name -r)
curl -sSLO https://github.com/sovereignCloudStack/cluster-stack-operator/releases/download/${CSO_VERSION}/cso-infrastructure-components.yaml
# CSPO manifests
CSPO_VERSION=$(curl https://api.github.com/repos/SovereignCloudStack/cluster-stack-provider-openstack/releases/latest -s | jq .name -r)
curl -sSLO https://github.com/sovereignCloudStack/cluster-stack-provider-openstack/releases/download/${CSPO_VERSION}/cspo-infrastructure-components.yaml
$ENVSUBST < cso-infrastructure-components.yaml | kubectl apply -f -
$ENVSUBST < cspo-infrastructure-components.yaml | kubectl apply -f -
# Prepare for cluster templates
# Create clouds.yaml (with app credential)
if test ! -r clouds.yaml; then
	#APPCREDS=$(openstack application credential list -f value -c ID -c Name -c "Project ID")
	APPCRED=$(openstack application credential show $PREFIX-$NAME  >/dev/null)
	if test $? = 0; then
		echo "App Cred $PREFIX-CSPO exists, but no clouds.yaml, please delete it" 1>&2
		exit 2
	fi
	# restricted AppCred should be OK, as we don't create dependant Sub-AppCreds, so no --unsrestricted
	NEWCRED=$(openstack application credential create "$PREFIX-$NAME" --description "App Cred $PREFIX for $NAME" -f value -c id -c project_id -c secret)
	if test $? != 0; then
		echo "Application Credential generation failed." 1>&2
		exit 2
	fi
	read APPCRED_ID APPCRED_PRJ APPCRED_SECRET < <(echo $NEWCRED)
	echo "#Created AppCred $APPCRED_ID"
	AUTH_URL=$(print-cloud.py | yq eval .clouds.${OS_CLOUD}.auth.auth_url -)
	REGION=$(print-cloud.py | yq eval .clouds.${OS_CLOUD}.region_name -)
	CACERT=$(print-cloud.py | yq eval '.clouds."'"$OS_CLOUD"'".cacert // "null"' -)
	# In theory we could also make interface and id_api_vers variable,
	# but let's do that once we find the necessity. Error handling makes
	# it slightly complex, so it's not an obvious win.
	cat >clouds.yaml <<EOT
clouds:
  #$PREFIX-$NAME:
  openstack:
    interface: public
    identity_api_version: 3
    region_name: $REGION
    cacert: $CACERT
    auth_type: "v3applicationcredential"
    auth:
      auth_url: $AUTH_URL
      #project_id: $APPCRED_PRJ
      application_credential_id: $APPCRED_ID
      application_credential_secret: "$APPCRED_SECRET"
EOT
	if test "$CACERT" == "null"; then
		sed -i '/    cacert:/d' clouds.yaml
	fi
	# And remove secret from env
	unset APPCRED_SECRET NEWCRED
fi
chmod 0640 clouds.yaml
# export OS_CLOUD=openstack
# Create secret from clouds.yaml
#curl -sSL https://github.com/SovereignCloudStack/cluster-stacks/releases/download/openstack-alpha-1-28-v3/csp-helper-chart.tgz | tar xv
#rm -f openstack-csp-helper/templates/namespace.yaml
curl -sSL https://github.com/SovereignCloudStack/openstack-csp-helper/releases/download/latest/openstack-csp-helper.tgz | tar xv
# Replace namespace
sed -i "/^{{\\- if include \"isAppCredential\" \\. \\-}}/{n
i$CLUSTER
d
}" openstack-csp-helper/templates/_helpers.tpl
# kubectl create ns $CLUSTER	# Not needed, helm csp-helper does it
helm upgrade --create-namespace -n $CLUSTER -i $CLUSTER-credentials openstack-csp-helper -f clouds.yaml >/dev/null
# Store an example cluster-stack
# Note: These should preferably be taken from the checked out repos.
# Currently, we use the content from https://input.scs.community/_HeOTRCRSu2Uf2SfMSoOkQ?both#
cat > clusterstack-alpha-1-29-v3-$CLUSTER.yaml <<EOT
apiVersion: clusterstack.x-k8s.io/v1alpha1
kind: ClusterStack
metadata:
  name: clusterstack
  namespace: $CLUSTER
spec:
  provider: openstack
  name: alpha
  kubernetesVersion: "1.29"
  channel: stable
  autoSubscribe: false
  providerRef:
    apiVersion: infrastructure.clusterstack.x-k8s.io/v1alpha1
    kind: OpenStackClusterStackReleaseTemplate
    name: cspotemplate
  versions:
    - v3
---
apiVersion: infrastructure.clusterstack.x-k8s.io/v1alpha1
kind: OpenStackClusterStackReleaseTemplate
metadata:
  name: cspotemplate
  namespace: $CLUSTER
spec:
  template:
    spec:
      identityRef:
        kind: Secret
        name: openstack
EOT
# No longer needed (part of openstack-csp-helper now)
cat >clusterresourceset-secret-$CLUSTER.yaml <<EOT
apiVersion: addons.cluster.x-k8s.io/v1beta1
kind: ClusterResourceSet
metadata:
 name: crs-openstack-secret
 namespace: $CLUSTER
spec:
 strategy: "Reconcile"
 clusterSelector:
   matchLabels:
     managed-secret: cloud-config
 resources:
   - name: openstack-workload-cluster-secret
     kind: Secret
EOT
cat >cluster-alpha-1-29-v3-$CLUSTER.yaml <<EOT
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: cs-$CLUSTER
  namespace: $CLUSTER
  labels:
    managed-secret: cloud-config
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - 192.168.0.0/16
    serviceDomain: cluster.local
    services:
      cidrBlocks:
        - 10.96.0.0/12
  topology:
    variables:
      - name: controller_flavor
        value: "SCS-2V-4-20s"
      - name: worker_flavor
        value: "SCS-2V-8-50"
      - name: external_id
        value: "$EXTID"
    class: openstack-alpha-1-29-v3
    controlPlane:
      replicas: 1
    version: v1.29.3
    workers:
      machineDeployments:
        - class: openstack-alpha-1-29-v3
          failureDomain: nova
          name: openstack-alpha-1-29-v3
          replicas: 3
EOT
#kubectl apply -f clusterresourceset-secret-$CLUSTER.yaml
echo "# Perform these to create a workload cluster (after editing as desired) ..."
echo "kubectl apply -f ~/$NAME/clusterstack-alpha-1-29-v3-$CLUSTER.yaml"
echo "kubectl apply -f ~/$NAME/cluster-alpha-1-29-v3-$CLUSTER.yaml"
# FIXME: Code from create_cluster.sh would help here ...
echo "# Wait for cluster to be ready ..."
echo "clusterctl -n $CLUSTER get kubeconfig cs-$CLUSTER > ~/$NAME/cs-$CLUSTER.yaml"

