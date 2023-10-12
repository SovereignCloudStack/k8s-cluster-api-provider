#!/bin/bash

sudo apt-get install --no-install-recommends --no-install-suggests -y fzf

# Deploy kubectx on mgmt cluster for convenience
git clone https://github.com/ahmetb/kubectx.git ~/.kubectx
COMPDIR=$(pkg-config --variable=completionsdir bash-completion)
ln -sf ~/.kubectx/completion/kubens.bash $COMPDIR/kubens
ln -sf ~/.kubectx/completion/kubectx.bash $COMPDIR/kubectx
cat << EOF >> ~/.bashrc

#kubectx and kubens
export PATH=~/.kubectx:\$PATH
alias kns=kubens
alias kctx=kubectx
EOF
