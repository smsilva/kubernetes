AZURE_BACKUP_SUBSCRIPTION_NAME="Azure subscription"
AZURE_SUBSCRIPTION_ID=$(az account list --query="[?name=='${AZURE_BACKUP_SUBSCRIPTION_NAME?}'].id | [0]" -o tsv)

az account set -s ${AZURE_SUBSCRIPTION_ID?}

az group list --query '[].{ ResourceGroup: name, Location:location }'

AZURE_BACKUP_RESOURCE_GROUP="Velero_Backups"

AZURE_AKS_NODE_RESOURCE_GROUP=$(az aks show \
  --name silvios-dev-eastus2 \
  --resource-group silvios-dev-eastus2 \
  --output tsv \
  --query nodeResourceGroup)

az group create \
  --name ${AZURE_BACKUP_RESOURCE_GROUP?} \
  --location "eastus2"

AZURE_STORAGE_ACCOUNT_ID="velero$(uuidgen | cut -d '-' -f5 | tr '[A-Z]' '[a-z]')"

az storage account create \
  --name ${AZURE_STORAGE_ACCOUNT_ID?} \
  --resource-group ${AZURE_BACKUP_RESOURCE_GROUP?} \
  --sku Standard_GRS \
  --encryption-services blob \
  --https-only true \
  --kind BlobStorage \
  --access-tier Hot

BLOB_CONTAINER="velero"

az storage container create \
  --name ${BLOB_CONTAINER?} \
  --public-access off \
  --account-name ${AZURE_STORAGE_ACCOUNT_ID?}

AZURE_TENANT_ID=`az account list --query '[?isDefault].tenantId' -o tsv`
AZURE_CLIENT_SECRET=`az ad sp create-for-rbac \
  --name "velero" \
  --role "Contributor" \
  --query 'password' -o tsv \
  --scopes /subscriptions/${AZURE_SUBSCRIPTION_ID?} /subscriptions/${AZURE_SUBSCRIPTION_ID?}`

AZURE_CLIENT_ID=`az ad sp list --display-name "velero" --query '[0].appId' -o tsv`

cat << EOF  > ./credentials-velero
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
AZURE_RESOURCE_GROUP=${AZURE_BACKUP_RESOURCE_GROUP}
AZURE_CLOUD_NAME=AzurePublicCloud
EOF

velero install \
  --provider azure \
  --plugins velero/velero-plugin-for-microsoft-azure:v1.2.0 \
  --bucket ${BLOB_CONTAINER?} \
  --secret-file ./credentials-velero \
  --use-restic \
  --backup-location-config resourceGroup=${AZURE_BACKUP_RESOURCE_GROUP?},storageAccount=${AZURE_STORAGE_ACCOUNT_ID?},subscriptionId=${AZURE_SUBSCRIPTION_ID?} \
  --snapshot-location-config resourceGroup=${AZURE_BACKUP_RESOURCE_GROUP?},subscriptionId=${AZURE_SUBSCRIPTION_ID?}

kubectl \
  --namespace velero \
  wait deployment velero \
  --for condition=Available \
  --timeout 3600s

velero backup-location get
