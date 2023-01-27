#!/bin/bash
export KUBECONFIG=~/.kube/config
. ~/bin/cccfg.inc
. ~/bin/openstack-kube-versions.inc

kubectl $KCONTEXT create secret generic cloud-config --from-file="$HOME/$CLUSTER_NAME/"cloud.conf -n kube-system #|| exit 6

cd ~/kubernetes-manifests.d
# install external cloud-provider openstack
KUBERNETES_VERSION=$(yq eval '.KUBERNETES_VERSION' $CCCFG)
DEPLOY_OCCM=$(yq eval '.DEPLOY_OCCM' $CCCFG)
if test "$DEPLOY_OCCM" = "null"; then DEPLOY_OCCM=true; fi
if test "$DEPLOY_OCCM" = "false"; then echo "ERROR: k8s will be uninitialized without occm" 1>&2; exit 1; fi
if test "$DEPLOY_OCCM" = "true"; then
  find_openstack_versions $KUBERNETES_VERSION
else
  find_openstack_versions $DEPLOY_OCCM
  if test "$OCCM_VERSION" = "$CCMR_VERSION"; then
    OCCM_VERSION=$DEPLOY_OCCM
    CCMR_VERSION=$DEPLOY_OCCM
  else
    OCCM_VERSION=$DEPLOY_OCCM
  fi
fi
echo "# Install external OpenStack cloud provider $OCCM_VERSION to $CLUSTER_NAME"

if test -n "$OCCM_VERSION"; then
  for name in openstack-cloud-controller-manager-ds.yaml openstack-cloud-controller-manager-pod.yaml; do
    NAME=${name%.yaml}-$OCCM_VERSION.yaml
    if test ! -s $NAME; then
      curl -L https://github.com/kubernetes/cloud-provider-openstack/raw/$OCCM_VERSION/manifests/controller-manager/$name -o $NAME
      echo -e "\n---" >> $NAME
      sed -i "s|\(docker.io/k8scloudprovider/openstack-cloud-controller-manager:\).*|\1$OCCM_VERSION|g" $NAME
    fi
  done
  OCCM=openstack-cloud-controller-manager-ds-$OCCM_VERSION.yaml
else
  OCCM=openstack.yaml
fi

if test -n "$CCMR_VERSION"; then
  for name in cloud-controller-manager-role-bindings.yaml cloud-controller-manager-roles.yaml; do
    NAME=${name%.yaml}-$CCMR_VERSION.yaml
    if test ! -s $NAME; then
      curl -L https://github.com/kubernetes/cloud-provider-openstack/raw/$CCMR_VERSION/manifests/controller-manager/$name -o $NAME
      echo -e "\n---" >> $NAME
    fi
  done
  cat cloud-controller-manager*-$CCMR_VERSION.yaml > cloud-controller-manager-rbac-$CCMR_VERSION.yaml
  CCMR=cloud-controller-manager-rbac-$CCMR_VERSION.yaml
else
  CCMR=cloud-controller-manager-rbac.yaml
fi
if grep '\-\-cluster\-name=' $OCCM >/dev/null 2>&1; then
	sed "/ *\- name: CLUSTER_NAME/{n
s/value: kubernetes/value: ${CLUSTER_NAME}/
}" $OCCM > ~/${CLUSTER_NAME}/deployed-manifests.d/openstack-cloud-controller-manager.yaml
else
	sed -e "/^            \- \/bin\/openstack\-cloud\-controller\-manager/a\            - --cluster-name=${CLUSTER_NAME}" \
	    -e "/^        \- \/bin\/openstack\-cloud\-controller\-manager/a\        - --cluster-name=${CLUSTER_NAME}" $OCCM > ~/${CLUSTER_NAME}/deployed-manifests.d/openstack-cloud-controller-manager.yaml
fi
cp -p $CCMR ~/${CLUSTER_NAME}/deployed-manifests.d/cloud-controller-manager-rbac.yaml
kubectl $KCONTEXT apply -f ~/${CLUSTER_NAME}/deployed-manifests.d/cloud-controller-manager-rbac.yaml || exit 7
kubectl $KCONTEXT apply -f ~/${CLUSTER_NAME}/deployed-manifests.d/openstack-cloud-controller-manager.yaml || exit 7

