AZURE_KEYVAULT_NAME="hashicorp-vault" && \
AZURE_KEYVAULT_KEY="unseal-keys" && \
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZURE_TENANT_ID=$(az account list --query="[?id=='${AZURE_SUBSCRIPTION_ID?}'].tenantId" -o tsv) && \
AZURE_KEYVAULT_SERVICE_PRINCIPAL_NAME="aks-key-vault" && \
AZURE_KEYVAULT_SERVICE_PRINCIPAL_SECRET=$(az ad sp create-for-rbac \
  --name "${AZURE_KEYVAULT_SERVICE_PRINCIPAL_NAME?}" \
  --role "Contributor" \
  --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID?}" \
  --query 'password' \
  --output tsv) && \
AZURE_KEYVAULT_SERVICE_PRINCIPAL_ID=$(az ad sp list \
  --display-name "${AZURE_KEYVAULT_SERVICE_PRINCIPAL_NAME?}" \
  --query [0].appId \
  --output tsv) && \
AZ_AKS_NODE_RESOURCE_GROUP_NAME="$(az aks show \
  --name ${AZ_AKS_CLUSTER_NAME?} \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}" \
  --query nodeResourceGroup \
  --output tsv)" && \
AZ_AKS_VNET_NAME=$(az network vnet list \
  --resource-group "${AZ_AKS_NODE_RESOURCE_GROUP_NAME?}" \
  --query [0].name \
  --output tsv) && \
AZ_AKS_VNET_SUBNET_NAME=$(az network vnet list \
  --resource-group "${AZ_AKS_NODE_RESOURCE_GROUP_NAME?}" \
  --query [0].subnets[0].name \
  --output tsv) && \
AZ_AKS_VNET_SUBNET_FOR_ACL="/subscriptions/${AZURE_SUBSCRIPTION_ID?}/resourceGroups/${AZ_AKS_NODE_RESOURCE_GROUP_NAME?}/providers/Microsoft.Network/virtualNetworks/${AZ_AKS_VNET_NAME?}/subnets/${AZ_AKS_VNET_SUBNET_NAME?}" && \
echo "" && \
echo "AZURE_SUBSCRIPTION_ID.........................: ${AZURE_SUBSCRIPTION_ID}" && \
echo "AZURE_TENANT_ID...............................: ${AZURE_TENANT_ID}" && \
echo "AZ_AKS_REGION.................................: ${AZ_AKS_REGION}" && \
echo "AZ_AKS_CLUSTER_NAME...........................: ${AZ_AKS_CLUSTER_NAME}" && \
echo "AZ_AKS_RESOURCE_GROUP_NAME....................: ${AZ_AKS_RESOURCE_GROUP_NAME}" && \
echo "AZ_AKS_NODE_RESOURCE_GROUP_NAME...............: ${AZ_AKS_NODE_RESOURCE_GROUP_NAME}" && \
echo "AZ_AKS_VNET_NAME..............................: ${AZ_AKS_VNET_NAME}" && \
echo "AZ_AKS_VNET_SUBNET_NAME.......................: ${AZ_AKS_VNET_SUBNET_NAME}" && \
echo "AZ_AKS_VNET_SUBNET_FOR_ACL....................: ${AZ_AKS_VNET_SUBNET_FOR_ACL}" && \
echo "AZURE_KEYVAULT_NAME...........................: ${AZURE_KEYVAULT_NAME}" && \
echo "AZURE_KEYVAULT_KEY............................: ${AZURE_KEYVAULT_KEY}" && \
echo "AZURE_KEYVAULT_SERVICE_PRINCIPAL_NAME.........: ${AZURE_KEYVAULT_SERVICE_PRINCIPAL_NAME}" && \
echo "AZURE_KEYVAULT_SERVICE_PRINCIPAL_ID...........: ${AZURE_KEYVAULT_SERVICE_PRINCIPAL_ID}" && \
echo "AZURE_KEYVAULT_SERVICE_PRINCIPAL_SECRET.......: ${AZURE_KEYVAULT_SERVICE_PRINCIPAL_SECRET}"

AZ_AKS_VNET_SUBNET_ID=$(az network vnet subnet show \
  --resource-group "${AZ_AKS_NODE_RESOURCE_GROUP_NAME}" \
  --vnet-name "${AZ_AKS_VNET_NAME}" \
  --name "${AZ_AKS_VNET_SUBNET_NAME}" \
  --query id \
  --output tsv)

az keyvault create \
  --name "${AZURE_KEYVAULT_NAME?}" \
  --location "${AZ_AKS_REGION?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"\
  --enabled-for-deployment true \
  --sku "standard" \
  --network-acls-vnets "${AZ_AKS_VNET_SUBNET_FOR_ACL?}"

az keyvault key create \
  --name "${AZURE_KEYVAULT_KEY?}" \
  --vault-name "${AZURE_KEYVAULT_NAME?}" \
  --kty "RSA" \
  --size 2048 \
  --ops 'verify' 'unwrapKey' 'wrapKey'

az keyvault key show \
--name "${AZURE_KEYVAULT_KEY?}" \
--vault-name "${AZURE_KEYVAULT_NAME?}" \
--output jsonc

az role assignment list -o jsonc --query="[?principalName=='http://aks-key-vault']"

az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee {i.e jalichwa@microsoft.com} \
  --scope /subscriptions/{subscriptionid}/resourcegroups/{resource-group-name}/providers/Microsoft.KeyVault/vaults/{key-vault-name}

cat <<EOF > config.hcl
seal "azurekeyvault" {
  client_id      = "${AZURE_KEYVAULT_SERVICE_PRINCIPAL_ID?}"
  client_secret  = "${AZURE_KEYVAULT_SERVICE_PRINCIPAL_SECRET?}"
  tenant_id      = "${AZURE_TENANT_ID?}"
  vault_name     = "test-vault-b70c7d3f"
  key_name       = "generated-key"
}
EOF

kubectl create secret generic vault-unseal-config \
  --from-file config.hcl \
  --namespace vault
