#!/bin/bash
# deploy_cindercsi.sh
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
if test -e clusterctl-${CLUSTER_NAME}.yaml; then CCCFG=clusterctl-${CLUSTER_NAME}.yaml; else CCCFG=clusterctl.yaml; fi
#NAMESPACE=$(yq eval .NAMESPACE $CCCFG)
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}" # "--namespace=$NAMESPACE"

echo "Install Cinder CSI persistent storage support to $CLUSTER_NAME"
# apply cinder-csi
DEPLOY_K8S_CINDERCSI_GIT=$(yq eval '.DEPLOY_K8S_CINDERCSI_GIT' $CCCFG)
if test "$DEPLOY_K8S_CINDERCSI_GIT" = "true"; then
  # deploy snapshot CRDs
  for name in snapshot.storage.k8s.io_volumesnapshotcontents.yaml snapshot.storage.k8s.io_volumesnapshotclasses.yaml snapshot.storage.k8s.io_volumesnapshots.yaml; do
    if ! test -r $name; then
	curl -LO https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/$name
	echo -e "\n---" >> $name
    fi
  done
  cat snapshot.storage.k8s.io_volumesnapshot* | kubectl $KCONTEXT apply -f - || exit 8
  # Now get cinder
  for name in cinder-csi-controllerplugin-rbac.yaml cinder-csi-controllerplugin.yaml cinder-csi-nodeplugin-rbac.yaml cinder-csi-nodeplugin.yaml csi-cinder-driver.yaml csi-secret-cinderplugin.yaml; do
    if ! test -r $name; then
        curl -LO https://github.com/kubernetes/cloud-provider-openstack/raw/master/manifests/cinder-csi-plugin/$name
	echo -e "\n---" >> $name
    fi
  done
  # Note: We leave out the secret which we should already have
  cat cinder-csi-*-rbac.yaml cinder-csi-*plugin.yaml csi-cinder-driver.yaml cinder-provider.yaml > cindercsi-git.yaml
  kubectl $KCONTEXT apply -f cindercsi-git.yaml || exit 8
else
  kubectl $KCONTEXT apply -f ~/external-snapshot-crds.yaml || exit 8
  kubectl $KCONTEXT apply -f ~/cinder.yaml || exit 8
fi

