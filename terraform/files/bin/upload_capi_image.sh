#!/usr/bin/env bash

. ~/bin/cccfg.inc

~/bin/fixup_k8s_version.sh $CCCFG
KUBERNETES_VERSION=$($YQ '.KUBERNETES_VERSION' $CCCFG)
. ~/bin/parse_k8s_version.inc
#UBU_IMG_NM=ubuntu-capi-image-$KUBERNETES_VERSION
UBU_IMG_NM=$($YQ '.OPENSTACK_IMAGE_NAME' $CCCFG)
IMG_RAW=$($YQ '.OPENSTACK_IMAGE_RAW' $CCCFG)
IMGREG_EXTRA=$($YQ '.OPENSTACK_IMAGE_REGISTRATION_EXTRA_FLAGS' $CCCFG)

VERSION_CAPI_IMAGE=$(echo $KUBERNETES_VERSION | sed 's/\.[[:digit:]]*$//g')
if test "$K8SVER" -ge 12703 ||
   test "$K8SVER" -lt 12700 -a "$K8SVER" -ge 12606 ||
   test "$K8SVER" -lt 12600 -a "$K8SVER" -ge 12511; then
  UBUVER=2204
  UBUVERS="22.04"
else
  UBUVER=2004
  UBUVERS="20.04"
fi

UBU_IMG=ubuntu-$UBUVER-kube-$KUBERNETES_VERSION

WAITLOOP=64
#download/upload image to openstack
CAPIIMG=$(openstack image list --name "$UBU_IMG_NM")
IMGURL=https://minio.services.osism.tech/openstack-k8s-capi-images
IMAGESRC=$IMGURL/ubuntu-$UBUVER-kube-$VERSION_CAPI_IMAGE/$UBU_IMG.qcow2
if test -z "$CAPIIMG"; then
  # TODO: Check signature
  wget $IMAGESRC
  FMT=qcow2
  IMGINFO=$(qemu-img info $UBU_IMG.qcow2)
  DISKSZ=$(echo "$IMGINFO" | grep '^virtual size' | sed 's/^[^(]*(\([0-9]*\) bytes).*$/\1/')
  DISKSZ=$(((DISKSZ+1073741823)/1073741824))
  IMGDATE=$(date -r $UBU_IMG.qcow2 +%F)
  if test ${IMGDATE:5:99} == "02-29"; then
    UNTIL=$((${IMGDATE:0:4}+1))-03-01
  else
    UNTIL=$((${IMGDATE:0:4}+1))-${IMGDATE:5:99}
  fi
  if test "$IMG_RAW" = "true"; then
    FMT=raw
    qemu-img convert $UBU_IMG.qcow2 -O raw -S 4k $UBU_IMG.raw && rm $UBU_IMG.qcow2 || exit 1
  fi
  #TODO min-disk, min-ram, other std. image metadata
  mkdir -p ~/tmp
  echo "Creating image $UBU_IMG_NM from $UBU_IMG.$FMT"
  nohup openstack image create --disk-format $FMT --min-ram 1024 --min-disk $DISKSZ --property image_build_date="$IMGDATE" --property image_original_user=ubuntu --property architecture=x86_64 --property hypervisor_type=kvm --property os_distro=ubuntu --property os_version="$UBUVERS" --property hw_disk_bus=scsi --property hw_scsi_model=virtio-scsi --property hw_rng_model=virtio --property image_source=$IMAGESRC --property image_description="https://github.com/osism/k8s-capi-images" --property kubernetes_version=$KUBERNETES_VERSION --property replace_frequency=never --property provided_until=$UNTIL --property uuid_validity=$UNTIL --tag managed_by_osism $IMGREG_EXTRA --file $UBU_IMG.$FMT $UBU_IMG_NM  > ~/tmp/img-create-$UBU_IMG_NM.out &
  CPID=$!
  sleep 5
  echo "Waiting for image $UBU_IMG_NM: "
  let -i ctr=0
  while test $ctr -le $WAITLOOP; do
    CAPIIMG=$(openstack image list --name "$UBU_IMG_NM" -f value -c ID -c Status)
    STATUS="${CAPIIMG##* }"
    if test "$STATUS" = "saving" -o "$STATUS" = "active"; then break; fi
    echo -n "."
    let ctr+=1
    sleep 10
  done
  echo " $CAPIIMG"
  if test $ctr -ge $WAITLOOP; then
    echo "ERROR: Image $UBU_IMG_NM not found" 1>&2
    exit 2
  fi
  # wait $CPID
  rm $UBU_IMG.$FMT
fi
