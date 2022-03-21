# Table of kubernetes and openstack versions
# (c) Kurt Garloff <kurt@garloff.de>, 3/2022
# SPDX-License-Identifier: CC-BY-SA-4.0
k8s_versions=("v1.19" "v1.20" "v1.21" "v1.22" "v1.23")
# OCCM, Cinder CSI, Manila CIS
occm_versions=("" "" "v1.0.0" "v1.1.2" "v1.2.0")
ccsi_versions=("" "" "v1.3.9" "v1.4.9" "v2.1.0")
mcsi_versions=("v0.2.2" "v1.0.0" "v1.1.1" "v1.3.3" "v1.4.0")

dotversion()
{
	VERS=${1#v}
	one=${VERS%%.*}
	two=${VERS#*.}
	three=${two#*.}
	if test $three=$two; then three=0; fi
	two=${two%%.*}
	VERSION=$((10000*$one+100*$two+$three))
	unset V one two three
	echo $VERSION
}

find_openstack_versions()
{
	k8s=${1:-$KUBERNETES_VERSION}
	k8vers=$(dotversion $k8s)
	if test -z "$k8s"; then echo "ERROR: Need to pass k8s version" 1>&2; return 1; fi
	NUMV=${#k8s_versions[*]}
	k8min=$(dotversion ${k8s_versions[0]})
	k8max=$(dotversion ${k8s_versions[$((NUMV-1))]})
	#echo "$k8vers $k8min $k8max"
	if test $k8vers -lt $k8min; then echo MIN; fi
	if test $k8vers -gt $((k8max+99)); then echo MAX; fi
	declare -i idx=0
	for k8 in ${k8s_versions[*]}; do
		k8test=$(dotversion $k8)
		if test $k8vers -ge $k8test -a $k8vers -le $((k8test+99)); then echo "Found $k8 ($idx)"; break; fi
		let idx+=1
	done
}
			

