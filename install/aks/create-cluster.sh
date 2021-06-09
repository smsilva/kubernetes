#!/bin/bash
CONFIG_FILE_NAME=$1

. ./load-config.sh ${CONFIG_FILE_NAME?}
. ./show-config.sh

az group create \
  --location "${AZ_AKS_REGION?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"

az aks create \
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}" \
  --kubernetes-version "${AZ_AKS_CLUSTER_VERSION?}" \
  --enable-aad \
  --network-plugin azure \
  --aad-admin-group-object-ids "${AZ_AKS_ADMIN_GROUP_ID?}" \
  --enable-managed-identity \
  --enable-cluster-autoscaler \
  --node-count 1 \
  --min-count 1 \
  --max-count 5 \
  --max-pods 120

az aks get-credentials \
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"
