#!/usr/bin/env bash

. ~/bin/cccfg.inc

KUBERNETES_VERSION=$(yq eval '.KUBERNETES_VERSION' $CCCFG)
UBU_IMG_NM=$(yq eval '.OPENSTACK_IMAGE_NAME' $CCCFG)

#download/upload image to openstack
echo -n "Waiting for image $UBU_IMG_NM to become active: "
let -i ctr=0
while test $ctr -lt 180; do
  CAPIIMG=$(openstack image list --name "$UBU_IMG_NM" -f value -c ID -c Status)
  if test -z "$CAPIIMG"; then
    echo "Image $UBU_IMG_NM does not exist, create ..."
    $HOME/bin/upload_capi_image.sh "$1" || exit $?
    continue
  fi
  if test "${CAPIIMG##* }" = "active"; then echo "$CAPIIMG"; break; fi
  echo -n "."
  let ctr+=1
  sleep 10
done
if test $ctr -ge 180; then echo "TIMEOUT"; exit 2; fi
