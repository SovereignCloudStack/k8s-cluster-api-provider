#!/usr/bin/env bash

##    desc: bootstrap a cluster-api environment for openstack
## license: Apache-2.0

# Find helper scripts
export PATH=$PATH:~/bin

# Need yaml parsing capabilities
sudo snap install yq

# Install k8s-cluster-api-provider repo
git clone https://github.com/SovereignCloudStack/k8s-cluster-api-provider || exit 1
if test -n "$1"; then cd k8s-cluster-api-provider; git checkout "$1" || exit 1; cd ..; fi
# Create links
ln -s k8s-cluster-api-provider/terraform/files/bin .
ln -s k8s-cluster-api-provider/terraform/files/kubernetes-manifests.d .

# Prepare OpenStack
prepare_openstack.sh
# Start image registration early, so it can proceed in the background
upload_capi_image.sh

## install tools and utils at local account

# install kubectl
sudo snap install kubectl --classic
sudo apt install -y binutils
sudo snap install kustomize

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
install_flux.sh
get_capi_helm.sh

#git clone https://github.com/Pharb/kubernetes-iperf3.git

CONTROLLERS=`yq eval '.CONTROL_PLANE_MACHINE_COUNT' ~/cluster-defaults/clusterctl.yaml`
if test "$CONTROLLERS" != "0"; then
    create_cluster.sh testcluster
fi
# Extensions
cd extension
for script in $(find ./ -name '*.sh' | sort)
do
    echo executing $script
    bash $script
done
# eof
