#!/bin/bash
. ~/.capi-settings
export OS_CLOUD=$(yq eval '.OPENSTACK_CLOUD' ~/cluster-defaults/clusterctl.yaml)

#install Openstack CLI
sudo apt install --no-install-recommends --no-install-suggests -y python3-openstackclient python3-octaviaclient
# fix bug 1876317
sudo patch -p2 -N -d /usr/lib/python3/dist-packages/keystoneauth1 < /tmp/fix-keystoneauth-plugins-unversioned.diff

# convenience
echo "export OS_CLOUD=\"$OS_CLOUD\"" >> $HOME/.bash_aliases

# Determine project ID and inject into cloud.conf
PROJECTID=$(openstack application credential show "${PREFIX}-appcred" -f value -c project_id)
echo "Set tenant-id to $PROJECTID for $OS_CLOUD"
if ! grep '^tenant.id' ~/cluster-defaults/cloud.conf >/dev/null; then
  sed -i "/^application.credential.secret/atenant-id=$PROJECTID"  ~/cluster-defaults/cloud.conf
fi

