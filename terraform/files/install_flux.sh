#!/bin/bash
# TODO: Check sig
if test -x /usr/local/bin/flux; then exit 0; fi
curl -s https://fluxcd.io/install.sh > install-flux2.sh
chmod +x install-flux2.sh
sudo ./install-flux2.sh
flux completion bash > ~/.bash_flux
echo "source ~/.bash_flux" >> ~/.bash_aliases
# flux install
