#!/bin/bash
# deploy_cindercsi.sh

# imports
. ~/bin/utils.inc
. ~/bin/cccfg.inc
. ~/bin/openstack-kube-versions.inc
. ~/$CLUSTER_NAME/harbor-settings

# Switch to capi workload cluster
if [ -z ${KCONTEXT} ]; then
  setup_kubectl_context_workspace
  set_workload_cluster_kubectl_namespace
fi

# apply cinder-csi
KUBERNETES_VERSION=$(yq eval '.KUBERNETES_VERSION' $CCCFG)
DEPLOY_CINDERCSI=$(yq eval '.DEPLOY_CINDERCSI' $CCCFG)
if test "$DEPLOY_CINDERCSI" = "null"; then DEPLOY_CINDERCSI=true; fi
cd ~/kubernetes-manifests.d/
if test "$DEPLOY_CINDERCSI" = "false"; then
  if test "$DEPLOY_HARBOR" = "true" -a "$HARBOR_PERSISTENCE" = "true"; then
    echo "INFO: Installation of Cinder CSI forced by Harbor deployment"
    DEPLOY_CINDERCSI=true
  else
    exit 1
  fi
fi
if test "$DEPLOY_CINDERCSI" = "true"; then
  find_openstack_versions $KUBERNETES_VERSION
else
  find_openstack_versions $DEPLOY_CINDERCSI
  CCSI_VERSION=$DEPLOY_CINDERCSI
fi
echo "# Install Cinder CSI persistent storage support $CCSI_VERSION to $CLUSTER_NAME"

SNAP_VERSION="master"
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

# deploy snapshot controller
for name in rbac-snapshot-controller.yaml setup-snapshot-controller.yaml; do
  NAME=${name%.yaml}-$SNAP_VERSION.yaml
  if ! test -s $NAME; then
    curl -L https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAP_VERSION/deploy/kubernetes/snapshot-controller/$name -o $NAME
    echo -e "\n---" >> $NAME
  fi
  cat $NAME >> cindercsi-snapshot-$SNAP_VERSION.yaml
done

cp -p cindercsi-snapshot-$SNAP_VERSION.yaml ~/${CLUSTER_NAME}/deployed-manifests.d/cindercsi-snapshot.yaml

if test -n "$CCSI_VERSION"; then
  # Now get cinder
  for name in cinder-csi-controllerplugin-rbac.yaml cinder-csi-controllerplugin.yaml cinder-csi-nodeplugin-rbac.yaml cinder-csi-nodeplugin.yaml csi-cinder-driver.yaml csi-secret-cinderplugin.yaml; do
    NAME=${name%.yaml}-$CCSI_VERSION.yaml
    if ! test -s $NAME; then
        #curl -L https://github.com/kubernetes/cloud-provider-openstack/raw/master/manifests/cinder-csi-plugin/$name -o $NAME
        curl -L https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/$CCSI_VERSION/manifests/cinder-csi-plugin/$name -o $NAME
	echo -e "\n---" >> $NAME
    fi
  done
  # Note: We leave out the secret which we should already have
  cat cinder-csi-*-rbac-$CCSI_VERSION.yaml cinder-csi-*plugin-$CCSI_VERSION.yaml csi-cinder-driver-$CCSI_VERSION.yaml cinder-provider.yaml > cindercsi-$CCSI_VERSION.yaml
  # correct ccsi image version - workaround for the https://github.com/kubernetes/cloud-provider-openstack/issues/2094
  sed -i "s|\(docker.io/k8scloudprovider/cinder-csi-plugin:\).*|\1$CCSI_VERSION|g" cindercsi-$CCSI_VERSION.yaml
  CCSI=cindercsi-$CCSI_VERSION.yaml
else
  CCSI=cinder.yaml
fi
kubectl --context=$KCONTEXT apply -f ~/$CLUSTER_NAME/deployed-manifests.d/cindercsi-snapshot.yaml || exit 8
CACERT=$(print-cloud.py | yq eval '.clouds."'"$OS_CLOUD"'".cacert // "null"' -)
if test "$CACERT" != "null"; then
  CAMOUNT="/etc/ssl/certs" # see prepare_openstack.sh, CACERT is already injected in the k8s nodes
  CAVOLUME="cacert"
  declare -a plugins=("csi-cinder-controllerplugin" "csi-cinder-nodeplugin")
  for plugin in "${plugins[@]}"; do
    # test if volume exists - also need to provide default value(// empty array) in expression in case of missing volumes(array)
    volume=$(yq 'select(.metadata.name == "'"$plugin"'").spec.template.spec | (.volumes // (.volumes = []))[] | select(.name == "'"$CAVOLUME"'")' $CCSI)
    # if volume does not exist, inject CACERT volume
    if test -z "$volume"; then
      yq 'select(.metadata.name == "'"$plugin"'").spec.template.spec.volumes += [{"name": "'"$CAVOLUME"'", "hostPath": {"path": "'"$CAMOUNT"'"}}]' -i $CCSI
      yq '(select(.metadata.name == "'"$plugin"'").spec.template.spec.containers[] | select(.name == "cinder-csi-plugin").volumeMounts) += [{"name": "'"$CAVOLUME"'", "mountPath": "'"$CAMOUNT"'", "readOnly": true}]' -i $CCSI
    fi
  done
fi
sed "/ *\- name: CLUSTER_NAME/{n
s/value: .*\$/value: ${CLUSTER_NAME}/
}" $CCSI > ~/$CLUSTER_NAME/deployed-manifests.d/cindercsi.yaml
kubectl --context=$KCONTEXT apply -f ~/${CLUSTER_NAME}/deployed-manifests.d/cindercsi.yaml || exit 8

