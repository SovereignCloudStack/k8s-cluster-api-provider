#!/usr/bin/env bash

##    desc: a helper for deploy a workload cluster on mgmt cluster
## license: Apache-2.0

STARTTIME=$(date +%s)
# variables
CLUSTERAPI_TEMPLATE=cluster-template.yaml
CLUSTER_NAME=testcluster
if test -n "$1"; then CLUSTER_NAME="$1"; fi
KUBECONFIG_WORKLOADCLUSTER="${CLUSTER_NAME}.yaml"

# Switch to capi mgmt cluster
export KUBECONFIG=~/.kube/config
kubectl config use-context kind-kind || exit 1
# get the needed clusterapi-variables
echo "# show used variables for clustertemplate ${CLUSTERAPI_TEMPLATE}"
if test -e "$HOME/clusterctl-${CLUSTER_NAME}.yaml"; then
	cp -p "$HOME/clusterctl-${CLUSTER_NAME}.yaml" $HOME/.cluster-api/clusterctl.yaml
else
	cp -p $HOME/clusterctl.yaml $HOME/.cluster-api/clusterctl.yaml
fi
#clusterctl config cluster ${CLUSTER_NAME} --list-variables --from ${CLUSTERAPI_TEMPLATE}
clusterctl generate cluster "${CLUSTER_NAME}" --list-variables --from ${CLUSTERAPI_TEMPLATE} || exit 2

# the need variables are set to $HOME/.cluster-api/clusterctl.yaml
echo "# rendering clusterconfig from template"
if test -e "${CLUSTER_NAME}-config.yaml"; then
	echo "Warning: Overwriting config for ${CLUSTER_NAME}"
	echo "Hit ^C to interrupt"
	sleep 3
fi
#clusterctl config cluster ${CLUSTER_NAME} --from ${CLUSTERAPI_TEMPLATE} > rendered-${CLUSTERAPI_TEMPLATE}
clusterctl generate cluster "${CLUSTER_NAME}" --from ${CLUSTERAPI_TEMPLATE} > "${CLUSTER_NAME}-config.yaml"

# apply to the kubernetes mgmt cluster
echo "# apply configuration and deploy cluster ${CLUSTER_NAME}"
kubectl apply -f "${CLUSTER_NAME}-config.yaml" || exit 3

#Waiting for Clusterstate Ready
echo "Waiting for Cluster=Ready"
#wget https://gx-scs.okeanos.dev --quiet -O /dev/null
ping -c1 -w2 9.9.9.9 >/dev/null 2>&1
sleep 20
kubectl wait --timeout=10m --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} || exit 1
kubectl wait --timeout=5m --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} || exit 1
kubectl wait --timeout=5m --for=condition=Ready machine -l cluster.x-k8s.io/control-plane || exit 4

kubectl get secrets "${CLUSTER_NAME}-kubeconfig" --output go-template='{{ .data.value | base64decode }}' > "${KUBECONFIG_WORKLOADCLUSTER}" || exit 5
echo "kubeconfig for ${CLUSTER_NAME} in ${KUBECONFIG_WORKLOADCLUSTER}"
export KUBECONFIG=".kube/config:${KUBECONFIG_WORKLOADCLUSTER}"
MERGED=$(mktemp merged.yaml.XXXXXX)
kubectl config view --flatten > $MERGED
mv $MERGED .kube/config
export KUBECONFIG=.kube/config
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}"

SLEEP=0
until kubectl $KCONTEXT api-resources
do
    echo "[$SLEEP] waiting for api-server"
    sleep 10
    let SLEEP+=10
done

# Tweak calico MTU
# MTU=`yq eval '.MTU_VALUE' clusterctl.yaml`
# kubectl patch configmap/calico-config -n kube-system --type merge -p '{"data":{"veth_mtu": "'${MTU}'"}}'
# kubectl rollout restart daemonset calico-node -n kube-system

# create cloud.conf secret
echo "Install external OpenStack cloud provider"
kubectl $KCONTEXT create secret generic cloud-config --from-file="$HOME"/cloud.conf -n kube-system #|| exit 6

# install external cloud-provider openstack
DEPLOY_K8S_OPENSTACK_GIT=$(yq eval '.DEPLOY_K8S_OPENSTACK_GIT' clusterctl.yaml)
if test "$DEPLOY_K8S_OPENSTACK_GIT" = "true"; then
  for name in cloud-controller-manager-role-bindings.yaml cloud-controller-manager-roles.yaml openstack-cloud-controller-manager-ds.yaml openstack-cloud-controller-manager-pod.yaml; do
    if ! test -r $name; then
        curl -LO https://github.com/kubernetes/cloud-provider-openstack/raw/master/manifests/controller-manager/$name
	echo -e "\n---" >> $name
    fi
  done
  # Note: Do not deploy openstack-cloud-controller-manager-pod.yaml
  cat cloud-controller-manager*.yaml openstack-cloud-controller-manager-ds.yaml > openstack-git.yaml
  kubectl $KCONTEXT apply -f openstack-git.yaml || exit 7
else
  kubectl $KCONTEXT apply -f ~/openstack.yaml || exit 7
fi

# apply cinder-csi
DEPLOY_K8S_CINDERCSI_GIT=$(yq eval '.DEPLOY_K8S_CINDERCSI_GIT' clusterctl.yaml)
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

# Metrics server
# kubectl $KCONTEXT create -f https://raw.githubusercontent.com/pythianarora/total-practice/master/sample-kubernetes-code/metrics-server.yaml
# kubectl $KCONTEXT apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
DEPLOY_METRICS=$(yq eval '.DEPLOY_METRICS' clusterctl.yaml)
if test "$DEPLOY_METRICS" = "true"; then
    echo "Install metrics service"
    curl -L https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | sed '/        - --kubelet-use-node-status-port/a\        - --kubelet-insecure-tls' > metrics-server.yaml
    kubectl $KCONTEXT apply -f metrics-server.yaml || exit 9
fi

echo "Wait for control plane of ${CLUSTER_NAME}"
kubectl config use-context kind-kind
kubectl wait --timeout=20m cluster "${CLUSTER_NAME}" --for=condition=Ready || exit 10
#kubectl config use-context "${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
kubectl $KCONTEXT get pods --all-namespaces
kubectl get openstackclusters
# Hints
echo "Cluster ${CLUSTER_NAME} deployed in $(($(date +%s)-$STARTTIME))s"
if test "$DEPLOY_METRICS" != "true"; then
    echo "Use curl -L https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | sed '/        - --kubelet-use-node-status-port/a\\        - --kubelet-insecure-tls' | kubectl $KCONTEXT apply -f -  to deploy the metrics service"
fi
echo "Use kubectl $KCONTEXT wait --for=condition=Ready --timeout=10m -n kube-system pods --all to wait for all cluster components to be ready"
echo "Use $KCONTEXT parameter to kubectl to control the workload cluster"
# eof
