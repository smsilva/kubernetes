#!/bin/bash
ENVIRONMENT="dev" && \
AZ_SUBSCRIPTION="Azure subscription" && \
AZ_REGION="eastus2" && \
AZ_AKS_CLUSTER="${USER}-${ENVIRONMENT}-${AZ_REGION}" && \
AZ_AKS_RESOURCE_GROUP_NAME="aks-${ENVIRONMENT}" && \
AZ_ACR_NAME="${USER}${ENVIRONMENT}"
AZ_ACR_REGION="${AZ_REGION}" && \
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

az acr login --name "${AZ_ACR_NAME}"

docker pull silviosilva/utils

IMAGE_NAME="${AZ_ACR_NAME}.azurecr.io/utils:1.0"

docker tag silviosilva/utils "${IMAGE_NAME}"

docker push "${IMAGE_NAME}"

az acr repository list \
  --name "${AZ_ACR_NAME}" \
  --output table

az acr repository show-tags \
  --name "${AZ_ACR_NAME}" \
  --repository utils \
  --output table

kubectl get events -w

kubectl run -it --image=${IMAGE_NAME} utils

az aks update \
  --name "${AZ_AKS_CLUSTER}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME}" \
  --attach-acr "${AZ_ACR_NAME}"

az role assignment list \
  --all \
  --subscription "${AZ_SUBSCRIPTION}" \
  --query "[?roleDefinitionName=='AcrPush']" \
  --output jsonc

az role assignment list \
  --all \
  --subscription "${AZ_SUBSCRIPTION}" \
  --query "[?roleDefinitionName=='AcrPull']" \
  --output jsonc

az aks update \
  --name "${AZ_AKS_CLUSTER}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME}" \
  --detach-acr "${AZ_ACR_NAME}"

az acr credential show \
  --name "${AZ_ACR_NAME}" \
  --resource-group "${AZ_ACR_RESOURCE_GROUP_NAME}"

AZ_DEVOPS_ORGANIZATION_NAME="silvios"
AZ_DEVOPS_PROJECT_NAME="Dummy_Project"

az repos list \
  --organization=https://dev.azure.com/${AZ_DEVOPS_ORGANIZATION_NAME}/ \
  --project=${AZ_DEVOPS_PROJECT_NAME} \
  --output table
