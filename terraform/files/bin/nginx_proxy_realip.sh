#!/bin/bash
# nginx_proxy_realip.sh
# Set proxy-real-ip-cidr in ingress-nginx-controller configmap to LB VIP
# (c) Kurt Garloff <garloff@osb-alliance.com>, 3/2022
# SPDX-License-Identifier: CC-BY-SA-4.0

. ~/bin/cccfg.inc

NGINX_YAML=~/$CLUSTER_NAME/deployed-manifests.d/nginx-ingress.yaml

get_ip_configmap()
{
	PROXYIP_K8S=$(kubectl $KCONTEXT describe -n ingress-nginx configmaps ingress-nginx-controller | grep -A2 proxy-real-ip-cidr | tail -n1)
}

get_ip_yaml()
{
	PROXYIP_YAML=$(yq eval '.data.proxy-real-ip-cidr' $NGINX_YAML | grep -v '^null' | grep -v '^\-\-\-')
}

get_ip_lb()
{
	PROXYIP_LB=$(openstack loadbalancer list --name=kube_service_${CLUSTER_NAME}_ingress-nginx_ingress-nginx-controller -f value -c vip_address)
	PROXYIP_LB="$PROXYIP_LB/32"
}

patch_ip_yaml()
{
	cp -p $NGINX_YAML $NGINX_YAML.bak
	sed -i "s@proxy-real-ip-cidr:.*\$@proxy-real-ip-cidr: \"$1\"@" $NGINX_YAML
	diff -up $NGINX_YAML.bak $NGINX_YAML
	kubectl $KCONTEXT apply -f $NGINX_YAML || return
	rm $NGINX_YAML.bak
}

reconcile()
{
	get_ip_configmap
	get_ip_yaml
	if test "$PROXYIP_K8S" != "$PROXYIP_YAML"; then echo "ERROR: K8S ConfigMap $PROXYIP_K8S, YAML $PROXYIP_YAML" 1>&2; fi
	get_ip_lb
	if test "$PROXYIP_K8S" != "$PROXYIP_LB"; then
		echo "#Info: Adjusting K8S nginx proxy-real-ip-cidr from $PROXYIP_K8S to $PROXYIP_LB" 1>&2
		patch_ip_yaml $PROXYIP_LB
		return 1
	fi
	return 0
}

test_enabled()
{
	DEPLOY_NGINX_INGRESS=$(yq eval '.DEPLOY_NGINX_INGRESS' $CCCFG)
	NGINX_INGRESS_PROXY=$(yq eval '.NGINX_INGRESS_PROXY' $CCCFG)
	if test "$DEPLOY_NGINX_INGRESS" = "false"; then echo "ERROR: DEPLOY_NGINX_INGRESS not enabled" 1>&2; return 1; fi
	if test "$NGINX_INGRESS_PROXY" != "true"; then echo "ERROR: NGINX_INGRESS_PROXY not set" 1>&2; return 2; fi
}


reconcile_loop()
{
	while true; do
		sleep 30
		test_enabled || exit $?
		reconcile
		sleep 90
	done
}

# main
if test "${0##*/}" = "nginx_proxy_realip.sh"; then
	test_enabled && reconcile && echo "#Info: Nothing to be done ($PROXYIP_LB)" 1>&2
fi
