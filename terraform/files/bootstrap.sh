#!/usr/bin/env bash

##    desc: bootstrap a cluster-api environment for openstack
## license: Apache-2.0

# Need yaml parsing capabilities
sudo snap install yq

# Prepare OpenStack
bash prepare_openstack.sh
# Start image registration early, so it can proceed in the background
bash upload_capi_image.sh

## install tools and utils at local account

# install kubectl
sudo snap install kubectl --classic
sudo apt install -y binutils
#sudo snap install kustomize

# setup aliases and environment
echo "# setup environment"
cat <<EOF >> ~/.bash_aliases
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

bash install_kind.sh
bash install_helm.sh
bash deploy_cluster_api.sh
bash install_k9s.sh
bash install_flux.sh
bash get_capi_helm.sh

CONTROLLERS=`yq eval '.CONTROL_PLANE_MACHINE_COUNT' clusterctl.yaml`
if test "$CONTROLLERS" != "0"; then
    bash create_cluster.sh testcluster
fi
# Extensions
cd extension
for script in $(find ./ -name '*.sh' | sort)
do
    echo executing $script
    bash $script
done
# eof
