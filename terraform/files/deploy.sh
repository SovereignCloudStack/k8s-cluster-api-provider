#!/usr/bin/env bash

##    desc: a helper for deploy a workload cluster on mgmt cluster
## license: Apache-2.0

# variables
CLUSTERAPI_OPENSTACK_PROVIDER_VERSION=0.3.4
CLUSTERAPI_TEMPLATE=cluster-template.yaml
CLUSTER_NAME=testcluster
KUBECONFIG_WORKLOADCLUSTER=workload-cluster.yaml

# get the clusterctl version
echo "show the clusterctl version:"
clusterctl version --output yaml

# set some Variables to the clusterctl.yaml
bash clusterctl_template.sh

# cp clusterctl.yaml to the right place
cp $HOME/clusterctl.yaml $HOME/.cluster-api/clusterctl.yaml

# deploy cluster-api on mgmt cluster
echo "deploy cluster-api with openstack provider ${CLUSTERAPI_OPENSTACK_PROVIDER_VERSION}"
clusterctl init --infrastructure openstack:v${CLUSTERAPI_OPENSTACK_PROVIDER_VERSION}

# wait for CAPI pods
echo "# wait for all components are ready for cluster-api"
kubectl wait --for=condition=Ready --timeout=5m -n capi-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capi-webhook-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capi-kubeadm-bootstrap-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capi-kubeadm-control-plane-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capo-system pod --all

# wait for CAPO crds
kubectl wait --for condition=established --timeout=60s crds/openstackmachines.infrastructure.cluster.x-k8s.io
kubectl wait --for condition=established --timeout=60s crds/openstackmachinetemplates.infrastructure.cluster.x-k8s.io
kubectl wait --for condition=established --timeout=60s crds/openstackclusters.infrastructure.cluster.x-k8s.io

# get the needed clusterapi-variables
echo "# show used variables for clustertemplate ${CLUSTERAPI_TEMPLATE}"
clusterctl config cluster ${CLUSTER_NAME} --list-variables --from ${CLUSTERAPI_TEMPLATE}

# the need variables are set to $HOME/.cluster-api/clusterctl.yaml
echo "# rendering clusterconfig from template"
clusterctl config cluster ${CLUSTER_NAME} --from ${CLUSTERAPI_TEMPLATE} > rendered-${CLUSTERAPI_TEMPLATE}

# apply to the kubernetes mgmt cluster
echo "# apply configuration and deploy cluster ${CLUSTER_NAME}"
kubectl apply -f rendered-${CLUSTERAPI_TEMPLATE}


#Waiting for Clusterstate Ready
echo "Waiting for Cluster=Ready"
wget https://gx-scs.okeanos.dev --quiet -O /dev/null
kubectl wait --timeout=10m --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}
kubectl wait --timeout=5m --for=condition=certificatesavailable kubeadmcontrolplanes --selector=cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}
kubectl wait --timeout=5m --for=condition=Ready machine -l cluster.x-k8s.io/control-plane

kubectl get secrets ${CLUSTER_NAME}-kubeconfig --output go-template='{{ .data.value | base64decode }}' > ${KUBECONFIG_WORKLOADCLUSTER}
export KUBECONFIG=.kube/config:${KUBECONFIG_WORKLOADCLUSTER}
kubectl config view --flatten > merged.yaml
mv merged.yaml .kube/config
kubectl config use-context ${CLUSTER_NAME}-admin@${CLUSTER_NAME}

SLEEP=0
until kubectl api-resources
do
    echo "[$SLEEP] waiting for api-server"
    sleep 10
    SLEEP=$(( SLEEP + 10 ))
done

# create cloud.conf secret
echo "Install external cloud provider"
kubectl create secret generic cloud-config --from-file="$HOME"/cloud.conf -n kube-system

# install external cloud-provider openstack
kubectl apply -f ~/openstack.yaml

# apply cinder-csi
kubectl apply -f ~/cinder.yaml

kubectl config use-context kind-kind
kubectl wait --timeout=30m cluster ${CLUSTER_NAME} --for=condition=Ready
kubectl config use-context ${CLUSTER_NAME}-admin@${CLUSTER_NAME}


# eof
