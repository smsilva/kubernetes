#!/bin/bash
set -e 

CONFIG_FILE_NAME=$1

if [ -z "${CONFIG_FILE_NAME}" ]; then
  echo "You must inform a config file name."
  exit 1
fi

if [ -e "${CONFIG_FILE_NAME?}" ]; then
  echo "The file ${CONFIG_FILE_NAME?} already exists."
  exit 1
else
  touch ${CONFIG_FILE_NAME?}
fi

AZ_USER_EMAIL="${AZ_USER_EMAIL:-smsilva@contoso.com}"
AZ_USER_ID=$(./find-azure-user-id.sh ${AZ_USER_EMAIL?})

AZ_AKS_ADMIN_GROUP_NAME="${AZ_AKS_ADMIN_GROUP_NAME-aks-administrator}"
AZ_AKS_ADMIN_GROUP_ID=$(./create-az-ad-group-for-aks-admin.sh ${AZ_USER_ID?} ${AZ_AKS_ADMIN_GROUP_NAME?})

ENVIRONMENT="sandbox"
AZ_AKS_REGION="eastus2"
AZ_AKS_RESOURCE_GROUP_NAME="${USER?}-${ENVIRONMENT?}-${AZ_AKS_REGION?}"
AZ_AKS_CLUSTER_NAME="${USER?}-${ENVIRONMENT?}-${AZ_AKS_REGION?}"
AZ_AKS_CLUSTER_VERSION_TARGET="1.18.14"
AZ_AKS_CLUSTER_VERSION="${AZ_AKS_CLUSTER_VERSION_TARGET:-$(az aks get-versions --location "${AZ_AKS_REGION?}" --output table | awk '{ print $1}' | grep -v preview | sed 1,2d | head -1)}"

cat <<EOF > ${CONFIG_FILE_NAME?}
AZ_USER_ID=${AZ_USER_ID?}
AZ_USER_EMAIL=${AZ_USER_EMAIL?}
AZ_AKS_ADMIN_GROUP_ID=${AZ_AKS_ADMIN_GROUP_ID?}
AZ_AKS_ADMIN_GROUP_NAME=${AZ_AKS_ADMIN_GROUP_NAME?}
AZ_AKS_REGION=${AZ_AKS_REGION?}
AZ_AKS_CLUSTER_VERSION=${AZ_AKS_CLUSTER_VERSION?}
AZ_AKS_CLUSTER_NAME=${AZ_AKS_CLUSTER_NAME?}
AZ_AKS_RESOURCE_GROUP_NAME=${AZ_AKS_RESOURCE_GROUP_NAME?}
EOF

. ./load-config.sh ${CONFIG_FILE_NAME?}
. ./show-config.sh
