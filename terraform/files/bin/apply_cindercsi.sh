#!/bin/bash
# deploy_cindercsi.sh
export KUBECONFIG=~/.kube/config
. ~/bin/cccfg.inc
. ~/bin/openstack-kube-versions.inc

# apply cinder-csi
KUBERNETES_VERSION=$(yq eval '.KUBERNETES_VERSION' $CCCFG)
DEPLOY_CINDERCSI=$(yq eval '.DEPLOY_CINDERCSI' $CCCFG)
if test "$DEPLOY_CINDERCSI" = "null"; then DEPLOY_CINDERCSI=true; fi
cd ~/kubernetes-manifests.d/
if test "$DEPLOY_CINDERCSI" = "false"; then exit 1; fi
if test "$DEPLOY_CINDERCSI" = "true"; then
  find_openstack_versions $KUBERNETES_VERSION
else
  find_openstack_versions $DEPLOY_CINDERCSI
  CCSI_VERSION=$DEPLOY_CINDERCSI
fi
echo "Install Cinder CSI persistent storage support $CCSI_VERSION to $CLUSTER_NAME"

if test -n "$SNAP_VERSION"; then
  # deploy snapshot CRDs
  for name in snapshot.storage.k8s.io_volumesnapshotcontents.yaml snapshot.storage.k8s.io_volumesnapshotclasses.yaml snapshot.storage.k8s.io_volumesnapshots.yaml; do
    NAME=${name%.yaml}-$SNAP_VERSION.yaml
    if ! test -s $NAME; then
	curl -L https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAP_VERSION/client/config/crd/$name -o $NAME
	echo -e "\n---" >> $NAME
    fi
  done
  # FIXME: Should we ignore non-working snapshots?
  cat snapshot.storage.k8s.io_volumesnapshot* > cindercsi-snapshot-$SNAP_VERSION.yaml
  cp -p cindercsi-snapshot-$SNAP_VERSION.yaml ~/${CLUSTER_NAME}/deployed-manifests.d/cindercsi-snapshot.yaml
else
  cp -p external-snapshot-crds.yaml ~/$CLUSTER_NAME/deployed-manifests.d/cindercsi-snapshot.yaml
fi

if test -n "$CCSI_VERSION"; then
  # Now get cinder
  for name in cinder-csi-controllerplugin-rbac.yaml cinder-csi-controllerplugin.yaml cinder-csi-nodeplugin-rbac.yaml cinder-csi-nodeplugin.yaml csi-cinder-driver.yaml csi-secret-cinderplugin.yaml; do
    NAME=${name%.yaml}-$CCSI_VERSION.yaml
    if ! test -s $NAME; then
        curl -L https://github.com/kubernetes/cloud-provider-openstack/raw/master/manifests/cinder-csi-plugin/$name -o $NAME
	echo -e "\n---" >> $NAME
    fi
  done
  # Note: We leave out the secret which we should already have
  cat cinder-csi-*-rbac-$CCSI_VERSION.yaml cinder-csi-*plugin-$CCSI_VERSION.yaml csi-cinder-driver-$CCSI_VERSION.yaml cinder-provider-$CCSI_VERSION.yaml > cindercsi-$CCSI_VERSION.yaml
  CCSI=cindercsi-$CCSI_VERSION.yaml
else
  CCSI=cinder.yaml
fi
kubectl $KCONTEXT apply -f ~/$CLUSTER_NAME/deployed-manifests.d/cindercsi-snapshot.yaml || exit 8
sed "/ *\- name: CLUSTER_NAME/{n
s/value: .*\$/value: ${CLUSTER_NAME}/
}" $CCSI > ~/$CLUSTER_NAME/deployed-manifests.d/cindercsi.yaml
kubectl $KCONTEXT apply -f ~/${CLUSTER_NAME}/deployed-manifests.d/cindercsi.yaml || exit 8

