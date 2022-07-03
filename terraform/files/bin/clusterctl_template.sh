#!/usr/bin/env bash
# Fill in OPENSTACK_CLOUD_YAML_B64, OPENSTACK_CLOUD_PROVIDER_CONF_B64,
#  OPENSTACK_CLOUD_CACERT_B64 into clusterctl.yaml

# yq installation done by bootstrap.sh
#sudo snap install yq
if test -z "$1"; then CLUSTER_NAME="cluster-defaults"; else CLUSTER_NAME="$1"; fi

# Encode clouds.yaml
# Using application credentials, we don't need project_id, and openstackclient is
# even confused (asking for scoped tokens which fails). However, the cluster-api-provider-openstack
# does not consider the AuthInfo to be valid of there is no projectID. It knows how to derive it
# from the name, but not how to derive it from an application credential. (Not sure gophercloud
# even has the needed helpers.)
if test -z "$PROJECTID"; then
  PROJECTID=$(grep 'tenant.id=' ~/$CLUSTER_NAME/cloud.conf | sed 's/^[^=]*=//')
else
  sed -i "s/^tenant.id=.*\$/tenant-id=$PROJECTID/" ~/$CLUSTER_NAME/cloud.conf
fi
#CLOUD_YAML_ENC=$( (cat ~/.config/openstack/clouds.yaml; echo "      project_id: $PROJECTID") | base64 -w 0)
OLD_OS_CLOUD=$(yq eval '.OPENSTACK_CLOUD' ~/$CLUSTER_NAME/clusterctl.yaml)
if test -z "$OS_CLOUD"; then
  OS_CLOUD=$OLD_OS_CLOUD
fi
CLOUD_YAML_ENC=$(print-cloud.py -s | sed 's/#project_id:/project_id:/' | base64 -w 0)
#echo $CLOUD_YAML_ENC

# Encode cloud.conf
CLOUD_CONF_ENC=$(base64 -w 0 ~/$CLUSTER_NAME/cloud.conf)
#echo $CLOUD_CONF_ENC

#Get CA and Encode CA
# Update OPENSTACK_CLOUD
if test "$OS_CLOUD" != "$OLD_OS_CLOUD"; then
  echo "#Info: Changing OPENSTACK_CLOUD frpm $OLD_OS_CLOUD to $OS_CLOUD"
  yq eval '.OPENSTACK_CLOUD = "'"$OS_CLOUD"'"' -i ~/$CLUSTER_NAME/clusterctl.yaml
  sed -i "/^OPENSTACK_CLOUD:/a\
OLD_OPENSTACK_CLOUD: $OLD_OS_CLOUD" ~/$CLUSTER_NAME/clusterctl.yaml
fi
# Snaps are broken - can not access ~/.config/openstack/clouds.yaml
AUTH_URL=$(print-cloud.py | yq eval .clouds.${OS_CLOUD}.auth.auth_url -)
#AUTH_URL=$(grep -A12 "${cloud_provider}" ~/.config/openstack/clouds.yaml | grep auth_url | head -n1 | sed -e 's/^ *auth_url: //' -e 's/"//g')
AUTH_URL_SHORT=$(echo "$AUTH_URL" | sed s'/https:\/\///' | sed s'/\/.*$//')
CERT_CERT=$(openssl s_client -connect "$AUTH_URL_SHORT" </dev/null 2>&1 | head -n 1 | sed s'/.*CN\ =\ //' | sed s'/\ /_/g' | sed s'/$/.pem/')
CLOUD_CA_ENC=$(base64 -w 0 /etc/ssl/certs/"$CERT_CERT")

yq eval '.OPENSTACK_CLOUD_YAML_B64 = "'"$CLOUD_YAML_ENC"'"' -i ~/$CLUSTER_NAME/clusterctl.yaml
yq eval '.OPENSTACK_CLOUD_PROVIDER_CONF_B64 = "'"$CLOUD_CONF_ENC"'"' -i ~/$CLUSTER_NAME/clusterctl.yaml
yq eval '.OPENSTACK_CLOUD_CACERT_B64 = "'"$CLOUD_CA_ENC"'"' -i ~/$CLUSTER_NAME/clusterctl.yaml

