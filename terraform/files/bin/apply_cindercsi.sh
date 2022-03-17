#!/bin/bash
# deploy_cindercsi.sh
export KUBECONFIG=~/.kube/config
. ~/bin/cccfg.inc

echo "Install Cinder CSI persistent storage support to $CLUSTER_NAME"
# apply cinder-csi
DEPLOY_K8S_CINDERCSI_GIT=$(yq eval '.DEPLOY_K8S_CINDERCSI_GIT' $CCCFG)
cd ~/kubernetes-manifests.d/
if test "$DEPLOY_K8S_CINDERCSI_GIT" = "true"; then
  # deploy snapshot CRDs
  for name in snapshot.storage.k8s.io_volumesnapshotcontents.yaml snapshot.storage.k8s.io_volumesnapshotclasses.yaml snapshot.storage.k8s.io_volumesnapshots.yaml; do
    if ! test -s $name; then
	curl -LO https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/$name
	echo -e "\n---" >> $name
    fi
  done
  # FIXME: Should we ignore non-working snapshots?
  cat snapshot.storage.k8s.io_volumesnapshot* > cindercsi-snapshot.yaml
  cp -p cindercsi-snapshot.yaml ~/${CLUSTER_NAME}/deployed-manifests.d/
  # Now get cinder
  for name in cinder-csi-controllerplugin-rbac.yaml cinder-csi-controllerplugin.yaml cinder-csi-nodeplugin-rbac.yaml cinder-csi-nodeplugin.yaml csi-cinder-driver.yaml csi-secret-cinderplugin.yaml; do
    if ! test -s $name; then
        curl -LO https://github.com/kubernetes/cloud-provider-openstack/raw/master/manifests/cinder-csi-plugin/$name
	echo -e "\n---" >> $name
    fi
  done
  # Note: We leave out the secret which we should already have
  cat cinder-csi-*-rbac.yaml cinder-csi-*plugin.yaml csi-cinder-driver.yaml cinder-provider.yaml > cindercsi-git.yaml
  CCSI=cindercsi-git.yaml
else
  # FIXME: Should we ignore non-working snapshots?
  cp -p external-snapshot-crds.yaml ~/$CLUSTER_NAME/deployed-manifests.d/cindercsi-snapshot.yaml
  CCSI=cinder.yaml
fi
kubectl $KCONTEXT apply -f ~/$CLUSTER_NAME/deployed-manifests.d/cindercsi-snapshot.yaml || exit 8
cat >cindercsi-${CLUSTER_NAME}.sed <<EOT
/ *\- name: CLUSTER_NAME/{
n
s/value: .*\$/value: ${CLUSTER_NAME}/
}
EOT
sed -f cindercsi-${CLUSTER_NAME}.sed $CCSI > ~/${CLUSTER_NAME}/deployed-manifests.d/cindercsi.yaml
kubectl $KCONTEXT apply -f ~/${CLUSTER_NAME}/deployed-manifests.d/cindercsi.yaml || exit 8

