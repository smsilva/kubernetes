#!/bin/bash

CONFIG_FILE="./cluster.config"

if ! [ -e ${CONFIG_FILE?} ]; then
  cp cluster-sample.config ${CONFIG_FILE?}
fi

source ${CONFIG_FILE?}

echo "GKE_CLUSTER_NAME............: ${GKE_CLUSTER_NAME?}"
echo "GKE_CLUSTER_RELEASE_CHANNEL.: ${GKE_CLUSTER_RELEASE_CHANNEL?}"
echo "GKE_CLUSTER_ZONE............: ${GKE_CLUSTER_ZONE?}"
echo "GKE_CLUSTER_NODE_LOCATIONS..: ${GKE_CLUSTER_NODE_LOCATIONS?}"
