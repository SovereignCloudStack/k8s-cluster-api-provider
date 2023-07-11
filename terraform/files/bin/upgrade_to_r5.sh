#!/bin/bash

# This script is used to update to a new cluster template for a new cluster generation.
# It will update a cluster-template.yaml and clusterctl.yaml file in the default cluster directory.

CLUSTER_NAME="$1"
if test -z "$CLUSTER_NAME"; then
  echo "Upgrading default configuration to R5..."
  echo "Note: For update of existing clusters, please use: upgrade_to_r5.sh CLUSTER_PATH"
  CLUSTER_PATH=$HOME/cluster-defaults/
else
  echo "Upgrading $CLUSTER_NAME to R5..."
  CLUSTER_PATH=$HOME/$CLUSTER_NAME

  if [ -d "$CLUSTER_PATH" ]; then
    echo "Cluster found, continuing..."
  else
    echo "Cluster not found, exiting..."
    exit 1
  fi
fi

# SERVICE AND POD CIDR UPDATE #454
# Update clusterctl.yaml to include the new CIDR variables
if grep -q "SERVICE_CIDR:" $CLUSTER_PATH/clusterctl.yaml; then
  echo "SERVICE_CIDR already set in clusterctl.yaml, skipping..."
else
  echo "Updating clusterctl.yaml with SERVICE_CIDR and POD CIDR..."
  sed -i.bak 's/^NODE_CIDR: /SERVICE_CIDR: 10.96.0.0\/12\nPOD_CIDR: 192.168.0.0\/16\nNODE_CIDR: /' $CLUSTER_PATH/clusterctl.yaml
fi

# Update cluster-template.yaml to include the new CIDR variables
if grep -q "cidrBlocks: \[\"192.168.0.0/16\"\]    # CIDR block used by Calico." $CLUSTER_PATH/cluster-template.yaml; then
  echo "Updating cluster-template.yaml with SERVICE_CIDR and POD CIDR..."
  sed -i.bak 's/cidrBlocks: \["192.168.0.0\/16"\]    # CIDR block used by Calico./cidrBlocks: \["$\{POD_CIDR\}"\]\n    services:\n      cidrBlocks: \["$\{SERVICE_CIDR\}"\]/' $CLUSTER_PATH/cluster-template.yaml
else
  echo "SERVICE_CIDR already set in cluster-template.yaml, skipping..."
fi
