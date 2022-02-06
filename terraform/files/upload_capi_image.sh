#!/usr/bin/env bash

CLUSTER_NAME=testcluster
if test -n "$1"; then CLUSTER_NAME="$1"; fi
KUBECONFIG_WORKLOADCLUSTER="${CLUSTER_NAME}.yaml"
if test -e "$HOME/clusterctl-${CLUSTER_NAME}.yaml"; then
	CCCFG="$HOME/clusterctl-${CLUSTER_NAME}.yaml"
else
	CCCFG=$HOME/clusterctl.yaml
fi

KUBERNETES_VERSION=$(yq eval '.KUBERNETES_VERSION' $CCCFG)
PROVIDER=$(yq eval '.OPENSTACK_CLOUD' $CCCFG)
#UBU_IMG_NM=ubuntu-capi-image-$KUBERNETES_VERSION
UBU_IMG_NM=$(yq eval '.OPENSTACK_IMAGE_NAME' $CCCFG)
IMG_RAW=$(yq eval '.OPENSTACK_IMAGE_RAW' $CCCFG)
IMGREG_EXTRA=$(yq eval '.OPENSTACK_IMAGE_REGISTRATION_EXTRA_FLAGS' $CCCFG)

VERSION_CAPI_IMAGE=$(echo $KUBERNETES_VERSION | sed 's/\.[[:digit:]]*$//g')
UBU_IMG=ubuntu-2004-kube-$KUBERNETES_VERSION

#download/upload image to openstack
CAPIIMG=$(openstack --os-cloud $PROVIDER image list --name $UBU_IMG_NM)
IMGURL=https://minio.services.osism.tech/openstack-k8s-capi-images
IMAGESRC=$IMGURL/ubuntu-2004-kube-$VERSION_CAPI_IMAGE/$UBU_IMG.qcow2
if test -z "$CAPIIMG"; then
  # TODO: Check signature
  wget $IMAGESRC
  FMT=qcow2
  IMGINFO=$(qemu-img info $UBU_IMG.qcow2)
  DIKKSZ=$(echo "$IMGINFO" | grep '^virtual size' | sed 's/^[^(]*(\([0-9]*\) bytes).*$/\1/')
  DISKSZ=$(((DISKSZ+1073741823)/1073741824))
  IMGDATE=$(date -r $UBU_IMG.qcow2 +%F)
  if test "$IMG_RAW" = "true"; then
    FMT=raw
    qemu-img convert $UBU_IMG.qcow2 -O raw -S 4k $UBU_IMG.raw && rm $UBU_IMG.qcow2 || exit 1
  fi
  #TODO min-disk, min-ram, other std. image metadata
  echo "Creating image $UBU_IMG_NM from $UBU_IMG.$FMT"
  openstack --os-cloud $PROVIDER image create --disk-format $FMT --min-ram 1024 --min-disk $DISKSZ --property image_build_date="$IMGDATE" --property image_original_user=ubuntu --property architecture=x86_64 --property hypervisor_type=kvm --property os_distro=ubuntu --property os_version="20.04" --property hw_disk_bus=scsi --property hw_scsi_model=virtio-scsi --property hw_rng_model=virtio --property image_source=$IMAGESRC --property kubernetes_version=$KUBERNETES_VERSION --tag managed_by_osism $IMGREG_EXTRA --file $UBU_IMG.$FMT $UBU_IMG_NM &
  sleep 5
  echo "Waiting for image $UBU_IMG_NM: "
  let -i ctr=0
  while test $ctr -le 64; do
    CAPIIMG=$(openstack --os-cloud $PROVIDER image list --name $UBU_IMG_NM -f value -c ID -c Status)
    STATUS="${CAPIIMG##* }"
    if test "$STATUS" = "saving" -o "$STATUS" = "active"; then break; fi
    echo -n "."
    let ctr+=1
    sleep 10
  done
  echo " $CAPIIMG"
  if test $ctr -ge 60; then
    echo "ERROR: Image $UBU_IMG_NM not found" 1>&2
    exit 2
  fi
  rm $UBU_IMG.$FMT
fi
