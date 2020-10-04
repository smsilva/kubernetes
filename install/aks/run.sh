#!/bin/bash

az account list -o table

az account list-locations -o table

AZ_REGION="eastus2" && \
AZ_RESOURCE_GROUP_NAME="aks-dev" && \
AKS_CLUSTER_NAME="dev-eastus2" && \
AKS_CLUSTER_VERSION="$(az aks get-versions --location "${AZ_REGION}" --output table | awk '{ print $1}' | grep -v preview | sed 1,2d | head -1)" && \
AKS_ADMIN_GROUP_IP="$(az ad group show -g myAKSAdminGroup --query objectId -o tsv)" && \
echo "AZ_REGION..............: ${AZ_REGION}" && \
echo "AZ_RESOURCE_GROUP_NAME.: ${AZ_RESOURCE_GROUP_NAME}" && \
echo "AKS_CLUSTER_NAME.......: ${AKS_CLUSTER_NAME}" && \
echo "AKS_CLUSTER_VERSION....: ${AKS_CLUSTER_VERSION}" && \
echo "AKS_ADMIN_GROUP_IP.....: ${AKS_ADMIN_GROUP_IP}" && \
echo ""

az aks get-versions \
  --location "${AZ_REGION}" \
  --output table

az group create \
  --location "${AZ_REGION}" \
  --resource-group "${AZ_RESOURCE_GROUP_NAME}"

az aks create \
  --resource-group "${AZ_RESOURCE_GROUP_NAME}" \
  --name "${AKS_CLUSTER_NAME}" \
  --kubernetes-version "${AKS_CLUSTER_VERSION}" \
  --enable-aad \
  --aad-admin-group-object-ids "${AKS_ADMIN_GROUP_IP}" \
  --node-count 1

az aks delete \
  --resource-group "${AZ_RESOURCE_GROUP_NAME}" \
  --name "${AKS_CLUSTER_NAME}" \
  --yes
