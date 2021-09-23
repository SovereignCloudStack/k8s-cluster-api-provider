#!/bin/bash
# This checks out
if test -e capi-helm-charts; then
	echo "Updating capi-helm-charts"
	cd capi-helm-charts
	git pull
else
	echo "Cloning capi-helm-charts"
	git clone https://github.com/stackhpc/capi-helm-charts
fi
