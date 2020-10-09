#!/bin/bash

USER_EMAIL="${USER_EMAIL:-smsilva@contoso.com}"

FILTER_EXPRESSION=$(printf "mail eq '%s'" "${USER_EMAIL}")
USER_ID=$(az ad user list --filter "${FILTER_EXPRESSION}" -o tsv --query='[*].objectId')

if [ -z "${USER_ID}" ]; then
  QUERY_EXPRESSION=$(printf "[?contains(otherMails, '%s')].objectId" "${USER_EMAIL}")
  USER_ID=$(az ad user list --query "${QUERY_EXPRESSION}" -o tsv)
fi

echo "USER_ID=${USER_ID}"

az ad user show --id ${USER_ID} -o jsonc

az ad user get-member-groups --id ${USER_ID} -o table

az account list -o table

az account set -s "<A_SUBSCRIPTION_DESCRIPTION_HERE>"

az account list-locations -o table

ENVIRONMENT="dev" && \
AZ_REGION="eastus2" && \
AZ_RESOURCE_GROUP_NAME="aks-${ENVIRONMENT}" && \
AKS_ADMIN_GROUP_NAME="myAKSAdminGroup" && \
AKS_CLUSTER_NAME="${ENVIRONMENT}-${AZ_REGION}" && \
AKS_CLUSTER_VERSION="$(az aks get-versions --location "${AZ_REGION}" --output table | awk '{ print $1}' | grep -v preview | sed 1,2d | head -1)" && \
AKS_ADMIN_GROUP_IP="$(az ad group show -g ${AKS_ADMIN_GROUP_NAME} --query objectId -o tsv)" && \
echo "USER_ID................: ${USER_ID}" && \
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
