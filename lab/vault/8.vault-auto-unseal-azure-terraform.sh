AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv) && \
AZURE_TENANT_ID=$(az account list --query="[?id=='${AZURE_SUBSCRIPTION_ID?}'].tenantId" -o tsv) && \
AZURE_TERRAFORM_SERVICE_PRINCIPAL_NAME="terraform" && \
AZURE_TERRAFORM_SERVICE_PRINCIPAL_SECRET=$(az ad sp create-for-rbac \
  --name "${AZURE_TERRAFORM_SERVICE_PRINCIPAL_NAME?}" \
  --role "Contributor" \
  --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID?}" \
  --query 'password' \
  --output tsv) && \
AZURE_TERRAFORM_SERVICE_PRINCIPAL_ID=$(az ad sp list \
  --display-name "${AZURE_TERRAFORM_SERVICE_PRINCIPAL_NAME?}" \
  --query [0].appId \
  --output tsv) && \
echo "" && \
echo "AZURE_SUBSCRIPTION_ID..........................: ${AZURE_SUBSCRIPTION_ID}" && \
echo "AZURE_TENANT_ID................................: ${AZURE_TENANT_ID}" && \
echo "AZURE_TERRAFORM_SERVICE_PRINCIPAL_NAME.........: ${AZURE_TERRAFORM_SERVICE_PRINCIPAL_NAME}" && \
echo "AZURE_TERRAFORM_SERVICE_PRINCIPAL_ID...........: ${AZURE_TERRAFORM_SERVICE_PRINCIPAL_ID}" && \
echo "AZURE_TERRAFORM_SERVICE_PRINCIPAL_SECRET.......: ${AZURE_TERRAFORM_SERVICE_PRINCIPAL_SECRET}"

az login \
  --service-principal \
  --username "${AZURE_TERRAFORM_SERVICE_PRINCIPAL_ID?}" \
  --password "${AZURE_TERRAFORM_SERVICE_PRINCIPAL_SECRET?}" \
  --tenant "${AZURE_TENANT_ID?}"

export ARM_CLIENT_ID="${AZURE_TERRAFORM_SERVICE_PRINCIPAL_ID?}"
export ARM_CLIENT_SECRET="${AZURE_TERRAFORM_SERVICE_PRINCIPAL_SECRET?}"
export ARM_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID?}"
export ARM_TENANT_ID="${AZURE_TENANT_ID?}"

git clone https://github.com/hashicorp/vault-guides.git

cd vault-guides/operations/azure-keyvault-unseal

cat <<EOF > terraform.tfvars
tenant_id="${AZURE_TENANT_ID?}"
public_key = "$(cat ~/.ssh/id_rsa.pub)"
client_id = "${AZURE_TERRAFORM_SERVICE_PRINCIPAL_ID?}"
client_secret = "${AZURE_TERRAFORM_SERVICE_PRINCIPAL_SECRET?}"
subscription_id = "${AZURE_SUBSCRIPTION_ID?}"
location="eastus2"
environment = "test"
EOF

terraform init

terraform plan

terraform apply -auto-approve

terraform output ssh-addr

vault status

vault operator init

vault status

sudo journalctl --no-pager -u vault

sudo systemctl restart vault

terraform destroy -auto-approve

cat <<EOF > config.hcl
seal "azurekeyvault" {
  client_id      = "${AZURE_TERRAFORM_SERVICE_PRINCIPAL_ID?}"
  client_secret  = "${AZURE_TERRAFORM_SERVICE_PRINCIPAL_SECRET?}"
  tenant_id      = "${AZURE_TENANT_ID?}"
  vault_name     = "test-vault-b70c7d3f"
  key_name       = "generated-key"
}
EOF

kubectl create secret generic vault-unseal-config \
  --from-file config.hcl \
  --namespace vault
