#!/usr/bin/env bash

##    desc: a helper for deploy a workload cluster on mgmt cluster
## license: Apache-2.0

# variables
. ~/.capi-settings

ARCH=$(uname -m | sed 's/x86_64/amd64/')
# Install clusterctl
echo "# install clusterctl $CLUSTERAPI_VERSION"
# TODO: Check signature
sudo curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v$CLUSTERAPI_VERSION/clusterctl-linux-$ARCH -o /usr/local/bin/clusterctl
sudo chmod +x /usr/local/bin/clusterctl

# get the clusterctl version
echo "show the clusterctl version:"
clusterctl version --output yaml

# set some Variables to the clusterctl.yaml
bash clusterctl_template.sh

# cp clusterctl.yaml to the right place
cp -p $HOME/clusterctl.yaml $HOME/.cluster-api/clusterctl.yaml

# deploy cluster-api on mgmt cluster
echo "deploy cluster-api with openstack provider $CLUSTERAPI_OPENSTACK_PROVIDER_VERSION"
clusterctl init --infrastructure openstack:v$CLUSTERAPI_OPENSTACK_PROVIDER_VERSION --core cluster-api:v$CLUSTERAPI_VERSION -b kubeadm:v$CLUSTERAPI_VERSION -c kubeadm:v$CLUSTERAPI_VERSION

# Install calicoctl
# TODO: Check signature
curl -o calicoctl -O -L "https://github.com/projectcalico/calico/releases/download/$CALICO_VERSION/calicoctl-linux-$ARCH"
if test $? != 0 -o $(stat -c "%s" calicoctl) -lt 1000; then
  curl -o calicoctl -O -L  "https://github.com/projectcalico/calicoctl/releases/download/$CALICO_VERSION/calicoctl"
fi
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin

# Install cilium
# TODO: Check signature
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-$ARCH.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-$ARCH.tar.gz.sha256sum || exit
sudo tar xzvfC cilium-linux-$ARCH.tar.gz /usr/local/bin
rm cilium-linux-$ARCH.tar.gz{,.sha256sum}
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-$ARCH.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-$ARCH.tar.gz.sha256sum || exit
sudo tar xzvfC hubble-linux-$ARCH.tar.gz /usr/local/bin
rm hubble-linux-$ARCH.tar.gz{,.sha256sum}

# wait for CAPI pods
echo "# wait for all components are ready for cluster-api"
kubectl wait --for=condition=Ready --timeout=5m -n capi-system pod --all
#kubectl wait --for=condition=Ready --timeout=5m -n capi-webhook-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capi-kubeadm-bootstrap-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capi-kubeadm-control-plane-system pod --all
kubectl wait --for=condition=Ready --timeout=5m -n capo-system pod --all

# wait for CAPO crds
kubectl wait --for condition=established --timeout=60s crds/openstackmachines.infrastructure.cluster.x-k8s.io
kubectl wait --for condition=established --timeout=60s crds/openstackmachinetemplates.infrastructure.cluster.x-k8s.io
kubectl wait --for condition=established --timeout=60s crds/openstackclusters.infrastructure.cluster.x-k8s.io

