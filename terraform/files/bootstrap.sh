#!/usr/bin/env bash

##    desc: bootstrap a cluster-api environment for openstack
## license: Apache-2.0

# version
VERSION_K9S="0.25.8"
VERSION_CLUSTERCTL="1.0.2"

# Start image registration early
bash upload_capi_image.sh

## install tools and utils at local account

# install kubectl
sudo snap install kubectl --classic
sudo apt install -y binutils

# install k9s
echo "# install k9s ${VERSION_K9S}"
# TODO: Check signature
curl -L https://github.com/derailed/k9s/releases/download/v${VERSION_K9S}/k9s_Linux_x86_64.tar.gz | tar zf - -x k9s
sudo mv ./k9s /usr/local/bin/k9s

# install clustercli
echo "# install clusterctl ${VERSION_CLUSTERCTL}"
# TODO: Check signature
sudo curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v${VERSION_CLUSTERCTL}/clusterctl-linux-amd64 -o /usr/local/bin/clusterctl
sudo chmod +x /usr/local/bin/clusterctl

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
bash get_capi_helm.sh
bash wait_capi_image.sh

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
