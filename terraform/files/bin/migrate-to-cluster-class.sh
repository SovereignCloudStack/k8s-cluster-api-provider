#!/bin/bash
# migrate-to-cluster-class.sh [CLUSTERNAME]
# Script is based on https://eng.d2iq.com/blog/adopting-existing-clusters-to-use-clusterclass/
# It migrates 'old' cluster templates to 'new' cluster class based templates
#
# (c) Roman Hros, 10/2023
# SPDX-License-Identifier: Apache-2.0

# imports
. ~/bin/utils.inc
. ~/bin/cccfg.inc

# Switch to capi mgmt cluster
setup_kubectl_context_workspace
set_workload_cluster_kubectl_namespace false

# https://cluster-api.sigs.k8s.io/tasks/experimental-features/experimental-features#enabling-experimental-features-on-existing-management-clusters
export KUBE_EDITOR="sed -i 's/ClusterTopology=false/ClusterTopology=true/'"
kubectl edit -n capi-system deployment.apps/capi-controller-manager
kubectl edit -n capi-kubeadm-control-plane-system deployment.apps/capi-kubeadm-control-plane-controller-manager
kubectl wait -n capi-system --for=condition=Ready pod --all
kubectl wait -n capi-kubeadm-control-plane-system --for=condition=Ready pod --all

# create control-plane template
CONTROL_PLANE_MACHINE_GEN=$(yq eval '.CONTROL_PLANE_MACHINE_GEN' $CCCFG)
CONTROL_PLANE=$(kubectl get KubeadmControlPlane/$CLUSTER_NAME-control-plane -o yaml)
KUBEADM_SPEC=$(echo "$CONTROL_PLANE" | yq .spec.kubeadmConfigSpec) \
NAME=$CLUSTER_NAME-control-plane-$CONTROL_PLANE_MACHINE_GEN \
API_VERSION=$(echo "$CONTROL_PLANE" | yq .apiVersion) \
yq --null-input '
  .apiVersion = env(API_VERSION) |
  .kind = "KubeadmControlPlaneTemplate" |
  .metadata = {"name": env(NAME)} |
  .spec = {"template": {"spec": {"kubeadmConfigSpec": env(KUBEADM_SPEC)}}}
  ' | kubectl apply -f -

# create openstack cluster template
OPENSTACK_CLUSTER=$(kubectl get OpenStackCluster/$CLUSTER_NAME -o yaml)
OPENSTACK_CLUSTER_API_VERSION=$(echo "$OPENSTACK_CLUSTER" | yq .apiVersion)
SPEC=$(echo "$OPENSTACK_CLUSTER" | yq '.spec | del(.controlPlaneEndpoint)') \
NAME=$CLUSTER_NAME \
API_VERSION=$OPENSTACK_CLUSTER_API_VERSION \
yq --null-input '
  .apiVersion = env(API_VERSION) |
  .kind = "OpenStackClusterTemplate" |
  .metadata = {"name": env(NAME)} |
  .spec = {"template": {"spec": env(SPEC)}}
  ' | kubectl apply -f -

# create cluster class
WORKER_MACHINE_GEN=$(yq eval '.WORKER_MACHINE_GEN' $CCCFG)
kubectl apply -f - <<EOF
apiVersion: cluster.x-k8s.io/v1beta1
kind: ClusterClass
metadata:
  name: ${CLUSTER_NAME}
spec:
  controlPlane:
    ref:
      apiVersion: controlplane.cluster.x-k8s.io/v1beta1
      kind: KubeadmControlPlaneTemplate
      name: "${CLUSTER_NAME}-control-plane-${CONTROL_PLANE_MACHINE_GEN}"
    machineInfrastructure:
      ref:
        kind: OpenStackMachineTemplate
        apiVersion: ${OPENSTACK_CLUSTER_API_VERSION}
        name: "${PREFIX}-${CLUSTER_NAME}-control-plane-${CONTROL_PLANE_MACHINE_GEN}"
    namingStrategy:
      template: "{{ .cluster.name }}-control-plane"
  infrastructure:
    ref:
      apiVersion: ${OPENSTACK_CLUSTER_API_VERSION}
      kind: OpenStackClusterTemplate
      name: ${CLUSTER_NAME}
  workers:
    machineDeployments:
    - class: "${PREFIX}-${CLUSTER_NAME}-md-0-no1"
      template:
        bootstrap:
          ref:
            apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
            kind: KubeadmConfigTemplate
            name: "${PREFIX}-${CLUSTER_NAME}-md-0-${WORKER_MACHINE_GEN}"
        infrastructure:
          ref:
            apiVersion: ${OPENSTACK_CLUSTER_API_VERSION}
            kind: OpenStackMachineTemplate
            name: "${PREFIX}-${CLUSTER_NAME}-md-0-${WORKER_MACHINE_GEN}"
      namingStrategy:
        template: "{{ .machineDeployment.topologyName }}"
EOF

# annotate cluster
# - add unsafe annotation (required to add topology to existing cluster)
# - remove kubectl annotation (problem with controlPlaneRef and infrastructureRef - missing in new templates)
kubectl annotate Cluster/$CLUSTER_NAME \
  unsafe.topology.cluster.x-k8s.io/disable-update-class-name-check= \
  kubectl.kubernetes.io/last-applied-configuration-

# label cluster
kubectl label Cluster/$CLUSTER_NAME OpenStackCluster/$CLUSTER_NAME \
  cluster.x-k8s.io/cluster-name=$CLUSTER_NAME \
  topology.cluster.x-k8s.io/owned=

# label resources based on the cluster label
kubectl label MachineSet,OpenStackMachine,Machine,KubeadmConfig \
  -l cluster.x-k8s.io/cluster-name=$CLUSTER_NAME \
    topology.cluster.x-k8s.io/owned=

# label control-plane
kubectl label \
  KubeadmControlPlane/$CLUSTER_NAME-control-plane \
  OpenStackMachineTemplate/$PREFIX-$CLUSTER_NAME-control-plane-$CONTROL_PLANE_MACHINE_GEN \
    cluster.x-k8s.io/cluster-name=$CLUSTER_NAME \
    topology.cluster.x-k8s.io/owned=

# label machinedeployment
kubectl label \
  MachineDeployment/$PREFIX-$CLUSTER_NAME-md-0-no1 \
  OpenStackMachineTemplate/$PREFIX-$CLUSTER_NAME-md-0-$WORKER_MACHINE_GEN \
  KubeadmConfigTemplate/$PREFIX-$CLUSTER_NAME-md-0-$WORKER_MACHINE_GEN \
    cluster.x-k8s.io/cluster-name=$CLUSTER_NAME \
    topology.cluster.x-k8s.io/deployment-name=$PREFIX-$CLUSTER_NAME-md-0-no1 \
    topology.cluster.x-k8s.io/owned=
kubectl label MachineSet,OpenStackMachine,Machine,KubeadmConfig \
  -l cluster.x-k8s.io/deployment-name=$PREFIX-$CLUSTER_NAME-md-0-no1 \
    topology.cluster.x-k8s.io/deployment-name=$PREFIX-$CLUSTER_NAME-md-0-no1

# remove kubectl annotation (problem with rootVolume: {} - missing in new templates) from OpenStackMachineTemplates
kubectl annotate \
  OpenStackMachineTemplate/$PREFIX-$CLUSTER_NAME-control-plane-$CONTROL_PLANE_MACHINE_GEN \
  OpenStackMachineTemplate/$PREFIX-$CLUSTER_NAME-md-0-$WORKER_MACHINE_GEN \
    kubectl.kubernetes.io/last-applied-configuration-

# patch machineset&machinedeployment selector and refs namespaces (were missing)
MACHINE_DEPLOYMENT_NAMESPACE=$(kubectl get MachineDeployment/$PREFIX-$CLUSTER_NAME-md-0-no1 -o jsonpath='{.metadata.namespace}')
cat <<EOF > machine-patch.yaml
spec:
  selector:
    matchLabels:
      cluster.x-k8s.io/cluster-name: $CLUSTER_NAME
      topology.cluster.x-k8s.io/deployment-name: $PREFIX-$CLUSTER_NAME-md-0-no1
      topology.cluster.x-k8s.io/owned: ""
  template:
    metadata:
      labels:
        cluster.x-k8s.io/cluster-name: $CLUSTER_NAME
        topology.cluster.x-k8s.io/deployment-name: $PREFIX-$CLUSTER_NAME-md-0-no1
        topology.cluster.x-k8s.io/owned: ""
    spec:
      bootstrap:
        configRef:
          namespace: $MACHINE_DEPLOYMENT_NAMESPACE
      infrastructureRef:
        namespace: $MACHINE_DEPLOYMENT_NAMESPACE
EOF
kubectl patch \
  $(kubectl get MachineSet -l cluster.x-k8s.io/cluster-name=$CLUSTER_NAME -o name) \
  MachineDeployment/$PREFIX-$CLUSTER_NAME-md-0-no1 \
    --type merge --patch-file machine-patch.yaml
rm machine-patch.yaml

# add cluster topology
KUBERNETES_VERSION=$(echo "$CONTROL_PLANE" | yq .spec.version)
CONTROL_PLANE_MACHINE_COUNT=$(yq eval '.CONTROL_PLANE_MACHINE_COUNT' $CCCFG)
WORKER_MACHINE_COUNT=$(yq eval '.WORKER_MACHINE_COUNT' $CCCFG)
OPENSTACK_FAILURE_DOMAIN=$(yq eval '.OPENSTACK_FAILURE_DOMAIN' $CCCFG)
cat <<EOF > cluster-patch.yaml
spec:
  topology:
    class: ${CLUSTER_NAME}
    version: ${KUBERNETES_VERSION}
    controlPlane:
      replicas: ${CONTROL_PLANE_MACHINE_COUNT}
    workers:
      machineDeployments:
      - class: "${PREFIX}-${CLUSTER_NAME}-md-0-no1"
        name: "${PREFIX}-${CLUSTER_NAME}-md-0-no1"
        replicas: ${WORKER_MACHINE_COUNT}
        failureDomain: ${OPENSTACK_FAILURE_DOMAIN}
EOF
kubectl patch Cluster/$CLUSTER_NAME --type merge --patch-file cluster-patch.yaml
rm cluster-patch.yaml
