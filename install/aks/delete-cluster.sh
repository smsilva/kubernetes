#!/bin/bash
CONFIG_FILE_NAME=$1

. ./load-config.sh ${CONFIG_FILE_NAME?}
. ./show-config.sh

az aks delete \
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"
