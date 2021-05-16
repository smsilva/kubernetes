#!/bin/bash
AZ_USER_ID=$1
AZ_AKS_ADMIN_GROUP_NAME=$2

az ad group create \
  --display-name ${AZ_AKS_ADMIN_GROUP_NAME?} \
  --mail-nickname ${AZ_AKS_ADMIN_GROUP_NAME?} \
  --only-show-errors > /dev/null

if [[ ! $(az ad group member check \
  --group ${AZ_AKS_ADMIN_GROUP_NAME?} \
  --member-id ${AZ_USER_ID?} \
  --query value \
  --output tsv) == "true" ]]; then
  az ad group member add \
    --group ${AZ_AKS_ADMIN_GROUP_NAME?} \
    --member-id ${AZ_USER_ID?} 2>&1 > /dev/null
fi

AZ_AKS_ADMIN_GROUP_ID="$(az ad group show \
  --group ${AZ_AKS_ADMIN_GROUP_NAME?} \
  --query objectId \
  --output tsv)"

echo ${AZ_AKS_ADMIN_GROUP_ID?}
