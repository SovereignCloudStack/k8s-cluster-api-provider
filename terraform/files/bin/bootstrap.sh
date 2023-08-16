#!/usr/bin/env bash

##    desc: bootstrap a cluster-api environment for openstack
## license: Apache-2.0

# Find helper scripts
export PATH=$PATH:~/bin

# Need yaml parsing capabilities
if type snap >/dev/null 2>&1; then sudo snap install yq; else sudo apt-get -y install yq; fi

# Source global settings
test -r ~/.capi-settings && source ~/.capi-settings

# Prepare OpenStack
prepare_openstack.sh
# Start image registration early, so it can proceed in the background
upload_capi_image.sh

## install tools and utils at local account

# install kubectl
sudo apt install -y binutils jq
if type snap >/dev/null 2>&1; then
  sudo snap install kubectl --classic
  sudo snap install kustomize
else
  apt-get install -y kubectl
  apt-get install -y kustomize
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

source ~/bin/yq.inc
# install Flux CLI always - regardless of deploy_flux variable(it can be used only for version change)
DEPLOY_FLUX=`$YQ '.DEPLOY_FLUX' ~/cluster-defaults/clusterctl.yaml`
if test "$DEPLOY_FLUX" = "true" -o "$DEPLOY_FLUX" = "false"; then
  FLUX_VERSION="0.41.2"
else
  FLUX_VERSION="${DEPLOY_FLUX:1}"
fi
install_flux.sh $FLUX_VERSION

#git clone https://github.com/Pharb/kubernetes-iperf3.git

CONTROLLERS=`$YQ '.CONTROL_PLANE_MACHINE_COUNT' ~/cluster-defaults/clusterctl.yaml`
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
