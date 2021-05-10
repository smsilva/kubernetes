#!/bin/bash

CONFIG_FILE_NAME="aks.conf"

if [ -e "${CONFIG_FILE_NAME}" ]; then
  source ${CONFIG_FILE_NAME}
fi

echo "AZ_AKS_CLUSTER_NAME........: ${AZ_AKS_CLUSTER_NAME}"
echo "AZ_AKS_RESOURCE_GROUP_NAME.: ${AZ_AKS_RESOURCE_GROUP_NAME}"

az aks delete \
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"
