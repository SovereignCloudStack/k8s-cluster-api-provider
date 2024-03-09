#!/bin/bash
#
# Bootstrap Cluster Stacks on a KaaS v1 management host
# (c) Kurt Garloff <garloff@osb-alliance.com>, 3/2024
# SPDX-License-Identifier: ASL-2.0
cd 
if test -e ~/.bash_aliases; then . ~/.bash_aliases; fi
# Check out repos
test_or_update()
{
	if test -d $1; then
		cd $1
		git update
		cd
	else
		git clone https://github.com/SovereignCloudStack/$1
	fi
}	
test_or_update cluster-stack-operator
test_or_update cluster-stack-provider-openstack
# envsubst helper (please always call with full path, as there is a name conflict)
sudo apt-get install golang-go
if test ! -x /usr/local/bin/envsubst; then
	mkdir -p ~/tmp
	GOBIN=~/tmp go install github.com/drone/envsubst/v2/cmd/envsubst@latest
	sudo mv ~/tmp/envsubst /usr/local/bin/
fi
# Deploy CSO and CSPO
if test -z "$GIT_ACCESS_TOKEN_B64"; then
	echo "Please set GIT_ACCESS_TOKEN_B64 in your ~/.bash_aliases"
	exit 1
fi
ENVSUBST=/usr/local/bin/envsubst
#$ENVSUBST <
