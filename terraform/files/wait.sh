#!/bin/bash

SLEEP=0
while [ ! -f /var/lib/cloud/instance/boot-finished ]
do
	echo "[$SLEEP] waiting for cloud-init to finish"
	sleep 10
    SLEEP=$(( SLEEP + 10 ))
done
