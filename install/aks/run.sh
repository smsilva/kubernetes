#!/bin/bash
CONFIG_FILE_NAME="environment.conf"

if [ -e "${CONFIG_FILE_NAME}" ]; then
  source environment.conf
fi

USER_EMAIL="${USER_EMAIL:-smsilva@contoso.com}"

FILTER_EXPRESSION=$(printf "mail eq '%s'" "${USER_EMAIL}")
USER_ID=$(az ad user list --filter "${FILTER_EXPRESSION}" -o tsv --query='[*].objectId')

if [ -z "${USER_ID}" ]; then
  QUERY_EXPRESSION=$(printf "[?contains(otherMails, '%s')].objectId" "${USER_EMAIL}")
  USER_ID=$(az ad user list --query "${QUERY_EXPRESSION}" -o tsv)
fi

# az ad user show --id ${USER_ID} -o jsonc

# az ad user get-member-groups --id ${USER_ID} -o table

ENVIRONMENT="dev" && \
AZ_AKS_REGION="eastus2" && \
AZ_AKS_RESOURCE_GROUP_NAME="aks-${ENVIRONMENT}" && \
AZ_AKS_ADMIN_GROUP_NAME="myAKSAdminGroup" && \
AZ_AKS_CLUSTER_NAME="${ENVIRONMENT}-${AZ_AKS_REGION}" && \
AZ_AKS_CLUSTER_VERSION="$(az aks get-versions --location "${AZ_AKS_REGION}" --output table | awk '{ print $1}' | grep -v preview | sed 1,2d | head -1)" && \
AZ_AKS_ADMIN_GROUP_IP="$(az ad group show -g ${AZ_AKS_ADMIN_GROUP_NAME} --query objectId -o tsv)" && \
echo "USER_ID....................: ${USER_ID}" && \
echo "USER_EMAIL.................: ${USER_EMAIL}" && \
echo "AZ_AKS_REGION..............: ${AZ_AKS_REGION}" && \
echo "AZ_AKS_RESOURCE_GROUP_NAME.: ${AZ_AKS_RESOURCE_GROUP_NAME}" && \
echo "AZ_AKS_CLUSTER_NAME........: ${AZ_AKS_CLUSTER_NAME}" && \
echo "AZ_AKS_CLUSTER_VERSION.....: ${AZ_AKS_CLUSTER_VERSION}" && \
echo "AZ_AKS_ADMIN_GROUP_IP......: ${AZ_AKS_ADMIN_GROUP_IP}" && \
echo ""

az group create \
  --location "${AZ_AKS_REGION}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME}"

az aks create \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME}" \
  --name "${AZ_AKS_CLUSTER_NAME}" \
  --kubernetes-version "${AZ_AKS_CLUSTER_VERSION}" \
  --enable-aad \
  --aad-admin-group-object-ids "${AZ_AKS_ADMIN_GROUP_IP}" \
  --node-count 1
