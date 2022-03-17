#!/bin/bash
# deploy_cindercsi.sh
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e ~/clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=~/clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=~/clusterctl.yaml; fi
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"

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
  cp -p snapshot.storage.k8s.io_volumesnapshot* "~/${CLUSTER_NAME}/"
  cat snapshot.storage.k8s.io_volumesnapshot* | kubectl $KCONTEXT apply -f - || exit 8
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
  kubectl $KCONTEXT apply -f external-snapshot-crds.yaml || exit 8
  CCSI=cinder.yaml
fi
cat >cindercsi-${CLUSTER_NAME}.sed <<EOT
/ *\- name: CLUSTER_NAME/{
n
s/value: .*\$/value: ${CLUSTER_NAME}/
}
EOT
sed -f cindercsi-${CLUSTER_NAME}.sed $CCSI > "~/${CLUSTER_NAME}/cindercsi.yaml
kubectl $KCONTEXT apply -f "~/${CLUSTER_NAME}/cindercsi.yaml || exit 8

