#!/bin/bash
. ~/.capi-settings
PROVIDER=$(yq eval '.OPENSTACK_CLOUD' ~/cluster-defaults/clusterctl.yaml)

#install Openstack CLI
sudo apt install -y python3-openstackclient python3-octaviaclient
# fix bug 1876317
sudo patch -p2 -N -d /usr/lib/python3/dist-packages/keystoneauth1 < ~/fix-keystoneauth-plugins-unversioned.diff

# convenience
echo "export OS_CLOUD=\"$PROVIDER\"" >> $HOME/.bash_aliases

# Determine project ID and inject into cloud.conf
PROJECTID=$(openstack --os-cloud="$PROVIDER" application credential show "${PREFIX}-appcred" -f value -c project_id)
echo "Set tenant-id to $PROJECTID for $PROVIDER"
if ! grep '^tenant.id' ~/cluster-defaults/cloud.conf >/dev/null; then
  sed -i "/^application.credential.secret/atenant-id=$PROJECTID"  ~/cluster-defaults/cloud.conf
fi
