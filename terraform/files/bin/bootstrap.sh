#!/usr/bin/env bash

##    desc: bootstrap a cluster-api environment for openstack
## license: Apache-2.0

# Find helper scripts
export PATH=$PATH:~/bin

# Need yaml parsing capabilities
# flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
if type snap >/dev/null 2>&1; then
  sudo snap install yq
else
  ARCH=`uname -m`
  if test "$ARCH" = "x86_64"; then ARCH=amd64; fi
  # FIXME: CHECK SIGNATURE
  curl -LO https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_$ARCH
  chmod +x yq_linux_$ARCH
  sudo mv yq_linux_$ARCH /usr/local/bin/yq
fi

# Source global settings
test -r ~/.capi-settings && source ~/.capi-settings

# Prepare OpenStack
prepare_openstack.sh
# Start image registration early, so it can proceed in the background
upload_capi_image.sh

## install tools and utils at local account

# install kubectl
sudo apt-get install --no-install-recommends --no-install-suggests -y binutils jq
if type snap >/dev/null 2>&1; then
  sudo snap install kubectl --classic
  sudo snap install kustomize
else
  sudo apt-get install --no-install-recommends --no-install-suggests -y apt-transport-https ca-certificates curl gnupg2
  # FIXME: CHECK SIGNATURE
  KUBECTLVER=v1.27
  curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBECTLVER/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  #sudo mkdir -m 755 /etc/apt/keyrings
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBECTLVER/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update
  sudo apt-get install -y kubectl
  # FIXME: CHECK SIGNATURE
  KUSTVER=v5.1.1
  curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/$KUSTVER/kustomize_${KUSTVER}_linux_amd64.tar.gz | tar xvz
  #chmod +x kustomize
  sudo mv kustomize /usr/local/bin/
fi

# setup aliases and environment
echo "# setup environment"
cat <<EOF >> ~/.bash_aliases
export PATH=\$PATH:~/bin
# kubernetes-cli
alias k=kubectl
source <( kubectl completion bash | sed 's# kubectl\$# k kubectl\$#' )
source <( kubectl completion bash )

# clusterctl
source <( clusterctl completion bash )

# Error code in prompt
PS1="\${PS1%\\\\\$ } [\\\$?]\\\$ "
# We may do git commits and nano feels unusual ...
export VISUAL=/usr/bin/vim
# eof
EOF

# openstack completion
openstack complete > ~/.bash_openstack 2>/dev/null
echo -e "#openstack completion\nsource ~/.bash_openstack" >> ~/.bash_aliases

# set inputrc set tab once
cat <<EOF > .inputrc
# set tab once
set show-all-if-ambiguous on
# alternate mappings for "page up" and "page down" to search the history
"\e[5~": history-search-backward
"\e[6~": history-search-forward
EOF

install_kind.sh
install_helm.sh
deploy_cluster_api.sh
install_k9s.sh
get_capi_helm.sh

# install Flux CLI always - regardless of deploy_flux variable(it can be used only for version change)
DEPLOY_FLUX=`yq eval '.DEPLOY_FLUX' ~/cluster-defaults/clusterctl.yaml`
if test "$DEPLOY_FLUX" = "true" -o "$DEPLOY_FLUX" = "false"; then
  FLUX_VERSION="0.41.2"
else
  FLUX_VERSION="${DEPLOY_FLUX:1}"
fi
install_flux.sh $FLUX_VERSION

#git clone https://github.com/Pharb/kubernetes-iperf3.git

CONTROLLERS=`yq eval '.CONTROL_PLANE_MACHINE_COUNT' ~/cluster-defaults/clusterctl.yaml`
export TESTCLUSTER=${1:-$TESTCLUSTER}
if test "$CONTROLLERS" != "0"; then
    create_cluster.sh $TESTCLUSTER
fi
# Extensions
cd extension
for script in $(find ./ -name '*.sh' | sort)
do
    echo executing $script
    bash $script
done
# eof
