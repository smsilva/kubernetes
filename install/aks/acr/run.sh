#!/bin/bash
ENVIRONMENT="dev" && \
AZ_AKS_CLUSTER="dev-eastus2" && \
AZ_AKS_RESOURCE_GROUP_NAME="aks-dev" && \
AZ_ACR_NAME="silviosdev"
AZ_ACR_REGION="eastus2" && \
AZ_ACR_RESOURCE_GROUP_NAME="acr-${ENVIRONMENT}" && \
echo "AZ_AKS_CLUSTER..................: ${AZ_AKS_CLUSTER}" && \
echo "AZ_AKS_RESOURCE_GROUP_NAME......: ${AZ_AKS_RESOURCE_GROUP_NAME}" && \
echo "AZ_ACR_NAME.....................: ${AZ_ACR_NAME}" && \
echo "AZ_ACR_REGION...................: ${AZ_ACR_REGION}" && \
echo "AZ_ACR_RESOURCE_GROUP_NAME......: ${AZ_ACR_RESOURCE_GROUP_NAME}" && \
echo ""

az group create \
  --name "${AZ_ACR_RESOURCE_GROUP_NAME}" \
  --location "${AZ_ACR_REGION}"

az acr create \
  --resource-group "${AZ_ACR_RESOURCE_GROUP_NAME}" \
  --name "${AZ_ACR_NAME}" \
  --sku "Premium"

az aks update \
  --name "${AZ_AKS_CLUSTER}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME}" \
  --attach-acr "${AZ_ACR_NAME}"

az acr login --name "${AZ_ACR_NAME}"

docker pull silviosilva/utils

IMAGE_NAME="${AZ_ACR_NAME}".azurecr.io/utils:1.0

docker tag silviosilva/utils "${IMAGE_NAME}"

docker push "${IMAGE_NAME}"

az acr repository list \
  --name "${AZ_ACR_NAME}" \
  --output table

az acr repository show-tags \
  --name "${AZ_ACR_NAME}" \
  --repository utils \
  --output table
