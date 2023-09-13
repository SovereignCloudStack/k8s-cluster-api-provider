#!/bin/bash

SLEEP=0
while [ ! -f /var/lib/cloud/instance/boot-finished ]
do
	echo "[${SLEEP}s] Waiting for cloud-init to finish"
	sleep 5
    SLEEP=$(( SLEEP + 5 ))
done
