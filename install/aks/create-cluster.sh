#!/bin/bash
CONFIG_FILE_NAME="aks.conf"

if [ -e "${CONFIG_FILE_NAME}" ]; then
  source ${CONFIG_FILE_NAME}
fi

AZ_USER_EMAIL="${AZ_USER_EMAIL:-smsilva@contoso.com}"

echo "AZ_USER_EMAIL..............: ${AZ_USER_EMAIL}"

FILTER_EXPRESSION=$(printf "mail eq '%s'" "${AZ_USER_EMAIL?}")

AZ_USER_ID=$(az ad user list \
  --filter "${FILTER_EXPRESSION?}" \
  --output tsv \
  --query='[*].objectId')

if [ -z "${AZ_USER_ID}" ]; then
  QUERY_EXPRESSION=$(printf "[?contains(otherMails, '%s')].objectId" "${AZ_USER_EMAIL?}")
  AZ_USER_ID=$(az ad user list \
    --query "${QUERY_EXPRESSION?}" \
    --output tsv)
fi

AZ_AKS_ADMIN_GROUP_NAME="aks-administrator" && \
az ad group create \
  --display-name ${AZ_AKS_ADMIN_GROUP_NAME?} \
  --mail-nickname ${AZ_AKS_ADMIN_GROUP_NAME?}

if [[ ! $(az ad group member check \
  --group ${AZ_AKS_ADMIN_GROUP_NAME?} \
  --member-id ${AZ_USER_ID?} \
  --query value \
  --output tsv) == "true" ]]; then
  az ad group member add \
    --group ${AZ_AKS_ADMIN_GROUP_NAME?} \
    --member-id ${AZ_USER_ID?}
fi

ENVIRONMENT="dev" && \
AZ_AKS_REGION="eastus2" && \
AZ_AKS_RESOURCE_GROUP_NAME="${USER?}-${ENVIRONMENT?}-${AZ_AKS_REGION?}" && \
AZ_AKS_CLUSTER_NAME="${USER?}-${ENVIRONMENT?}-${AZ_AKS_REGION?}" && \
AZ_AKS_CLUSTER_VERSION_TARGET="1.18.14" && \
AZ_AKS_CLUSTER_VERSION="${AZ_AKS_CLUSTER_VERSION_TARGET:-$(az aks get-versions --location "${AZ_AKS_REGION?}" --output table | awk '{ print $1}' | grep -v preview | sed 1,2d | head -1)}" && \
AZ_AKS_ADMIN_GROUP_ID="$(az ad group show \
  --group ${AZ_AKS_ADMIN_GROUP_NAME?} \
  --query objectId \
  --output tsv)" && \
echo "AZ_USER_ID.................: ${AZ_USER_ID}" && \
echo "AZ_USER_EMAIL..............: ${AZ_USER_EMAIL}" && \
echo "AZ_AKS_REGION..............: ${AZ_AKS_REGION}" && \
echo "AZ_AKS_RESOURCE_GROUP_NAME.: ${AZ_AKS_RESOURCE_GROUP_NAME}" && \
echo "AZ_AKS_CLUSTER_NAME........: ${AZ_AKS_CLUSTER_NAME}" && \
echo "AZ_AKS_CLUSTER_VERSION.....: ${AZ_AKS_CLUSTER_VERSION}" && \
echo "AZ_AKS_ADMIN_GROUP_ID......: ${AZ_AKS_ADMIN_GROUP_ID}"

cat <<EOF > ${CONFIG_FILE_NAME?}
AZ_USER_ID=${AZ_USER_ID?}
AZ_USER_EMAIL=${AZ_USER_EMAIL?}
AZ_AKS_ADMIN_GROUP_ID=${AZ_AKS_ADMIN_GROUP_ID?}
AZ_AKS_ADMIN_GROUP_NAME=${AZ_AKS_ADMIN_GROUP_NAME?}
AZ_AKS_REGION=${AZ_AKS_REGION?}
AZ_AKS_CLUSTER_NAME=${AZ_AKS_CLUSTER_NAME?}
AZ_AKS_CLUSTER_VERSION=${AZ_AKS_CLUSTER_VERSION?}
AZ_AKS_RESOURCE_GROUP_NAME=${AZ_AKS_RESOURCE_GROUP_NAME?}
EOF

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
  --enable-cluster-autoscaler \
  --node-count 1 \
  --min-count 1 \
  --max-count 5 \
  --max-pods 120

az aks get-credentials \
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"
