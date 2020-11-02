#!/usr/bin/env bash

##    desc: bootstrap a cluster-api environment for openstack
## license: Apache-2.0

# versions
VERSION_K9S="0.23.3"
VERSION_CLUSTERCTL="0.3.10"

## install tools and utils at local account
#
mkdir -p $HOME/bin

# install k9s
echo "# install k9s ${VERSION_CLUSTERCTL}"
curl -L https://github.com/derailed/k9s/releases/download/v${VERSION_K9S}/k9s_Linux_x86_64.tar.gz -o $HOME/bin/k9s && \
  chmod +x $HOME/bin/k9s

# install clusterapi-cli
echo "# install clusterctl ${VERSION_CLUSTERCTL}"
curl -sfL https://github.com/kubernetes-sigs/cluster-api/releases/download/v${VERSION_CLUSTERCTL}/clusterctl-linux-amd64 -o ~/bin/clusterctl && \
  chmod +x ~/bin/clusterctl

# setup aliases and environment
echo "# setup environment"
cat <<EOF > $HOME/.bash_aliases
# path
export PATH=\$PATH:\$HOME/bin

# kubernetes
alias k=kubectl
source <( kubectl completion bash | sed 's# kubectl\$# k kubectl\$#' )

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# clusterctl 
source <( clusterctl completion bash )

# eof
EOF

# set inputrc set tab once
cat <<EOF > .inputrc
# set tab one
set show-all-if-ambiguous on
EOF

source $HOME/.bash_aliases

## check system
#

# get k8s nodes
kubectl get nodes --output wide

# eof
