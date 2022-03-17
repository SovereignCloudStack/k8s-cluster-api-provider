#!/bin/bash
# If we have not hardcoded an MTU, discover the one from
# the running system and assume our cluster is on the same cloud
#CLOUDMTU=$(grep '^MTU_VALUE:' clusterctl.yaml | sed 's/MTU_VALUE: //')
if test -e /tmp/daemon.json && grep '"mtu":' /tmp/daemon.json >/dev/null; then
	CLOUDMTU=$(grep '"mtu":' /tmp/daemon.json | sed 's/^ *"mtu": *//' | tr -d '"')
	echo "Read MTU $CLOUDMTU from /tmp/daemon.json"
elif test -e /etc/docker/daemon.json && grep '"mtu":' /etc/docker/daemon.json >/dev/null; then
	CLOUDMTU=$(grep '"mtu":' /etc/docker/daemon.json | sed 's/^ *"mtu": *//' | tr -d '"')
	echo "Read MTU $CLOUDMTU from /etc/docker/daemon.json"
else
	CLOUDMTU=$(grep '^MTU_VALUE:' ~ubuntu/cluster-defaults/clusterctl.yaml | sed 's/MTU_VALUE: //')
	if test "$CLOUDMTU" != "0"; then let CLOUDMTU+=50; fi
	echo "Read MTU $CLOUDMTU from ~/cluster-defaults/clusterctl.yaml"
fi

if test "$CLOUDMTU" == "0"; then
	DEV=$(ip route show default | head -n1 | sed 's/^.*dev \([^ ]*\).*$/\1/')
	CLOUDMTU=$(ip link show $DEV | head -n1 | sed 's/^.*mtu \([0-9]*\) .*$/\1/')
	echo "Detected MTU $CLOUDMTU (dev $DEV)"
	DOCKERMTU=$((CLOUDMTU/8*8))
	if test -e /tmp/daemon.json && grep '"mtu": 0' /tmp/daemon.json >/dev/null; then
		if test "$CLOUDMTU" == "1500"; then rm /tmp/daemon.json; fi
		sed -i "s/: 0/: $DOCKERMTU/" /tmp/daemon.json
	fi
fi
CALICOMTU=$(((CLOUDMTU-50)/8*8))
sed -i "s/MTU_VALUE: 0/MTU_VALUE: $CALICOMTU/" ~ubuntu/cluster-defaults/clusterctl.yaml
