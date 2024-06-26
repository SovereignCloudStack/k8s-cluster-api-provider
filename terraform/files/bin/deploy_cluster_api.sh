#!/usr/bin/env bash

##    desc: a helper for deploy a workload cluster on mgmt cluster
## license: Apache-2.0

# variables
. ~/.capi-settings
. ~/bin/openstack-kube-versions.inc
. /etc/profile.d/proxy.sh

ARCH=$(uname -m | sed 's/x86_64/amd64/')
# Install clusterctl
echo "# install clusterctl $CLUSTERAPI_VERSION"
# TODO: Check signature
sudo curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v$CLUSTERAPI_VERSION/clusterctl-linux-$ARCH -o /usr/local/bin/clusterctl
sudo chmod +x /usr/local/bin/clusterctl

# Source .bash_aliases in case we are called from non-interactive bash (Makefile)
# This does not seem to be strictly needed for deploy_cluster_api.sh right now.
# We have moved it until after installation of clusterctl to avoid a cosmetic error.
source ~/.bash_aliases

# get the clusterctl version
echo "show the clusterctl version:"
clusterctl version --output yaml

# We used to encode secrets here for clusterctl.yaml
#bash clusterctl_template.sh
# This is done per cluster now, here's what's left:
# Generate SET_MTU_B64
#MTU=`yq eval '.MTU_VALUE' ~/cluster-defaults/clusterctl.yaml`
# Fix up nameserver list (trailing comma -- cosmetic)
sed '/OPENSTACK_DNS_NAMESERVERS:/s@, \]"@ ]"@' -i ~/cluster-defaults/clusterctl.yaml
# Fix metadata dicts (trailing comma -- cosmetic)
sed '/OPENSTACK_CONTROL_PLANE_MACHINE_METADATA:/s@, }"@ }"@' -i ~/cluster-defaults/clusterctl.yaml
sed '/OPENSTACK_NODE_MACHINE_METADATA:/s@, }"@ }"@' -i ~/cluster-defaults/clusterctl.yaml

# cp clusterctl.yaml to the right place
if test "$(dotversion "$(clusterctl version -o short)")" -ge 10500; then
  cp -p $HOME/cluster-defaults/clusterctl.yaml $HOME/.config/cluster-api/clusterctl.yaml
else
  cp -p $HOME/cluster-defaults/clusterctl.yaml $HOME/.cluster-api/clusterctl.yaml
fi

# deploy cluster-api on mgmt cluster
echo "deploy cluster-api with openstack provider $CLUSTERAPI_OPENSTACK_PROVIDER_VERSION"
export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure openstack:v$CLUSTERAPI_OPENSTACK_PROVIDER_VERSION --core cluster-api:v$CLUSTERAPI_VERSION -b kubeadm:v$CLUSTERAPI_VERSION -c kubeadm:v$CLUSTERAPI_VERSION

# Install calicoctl
# TODO: Check signature
CALICO_VERSION=`yq eval '.CALICO_VERSION' ~/cluster-defaults/clusterctl.yaml`
curl -o calicoctl -L "https://github.com/projectcalico/calico/releases/download/$CALICO_VERSION/calicoctl-linux-$ARCH"
if test $? != 0 -o $(stat -c "%s" calicoctl) -lt 1000; then
  curl -o calicoctl -L "https://github.com/projectcalico/calicoctl/releases/download/$CALICO_VERSION/calicoctl"
fi
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin

# Install cilium
# TODO: Check signature
#CILIUM_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
CILIUM_VERSION="${CILIUM_BINARIES%%;*}"
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/$CILIUM_VERSION/cilium-linux-$ARCH.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-$ARCH.tar.gz.sha256sum || exit
#https://github.com/cilium/cilium-cli/releases/download/v0.12.3/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-$ARCH.tar.gz /usr/local/bin
rm cilium-linux-$ARCH.tar.gz{,.sha256sum}
#HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_VERSION="${CILIUM_BINARIES##*;}"
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
kubectl wait --for condition=established --timeout=60s crds/openstackclustertemplates.infrastructure.cluster.x-k8s.io
