#!/bin/bash
. /etc/profile.d/proxy.sh
# TODO: Check sig
if test -x /usr/local/bin/flux; then exit 0; fi
curl -s https://fluxcd.io/install.sh > ~/bin/install-flux2.sh
chmod +x ~/bin/install-flux2.sh
# Install
FLUX_VERSION=$1 install-flux2.sh
flux completion bash > ~/.bash_flux
echo "source ~/.bash_flux" >> ~/.bash_aliases
