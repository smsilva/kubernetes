# https://dzone.com/articles/setup-velero-on-aks

AZURE_BACKUP_SUBSCRIPTION_NAME="Azure subscription" && \
AZURE_TENANT_ID=$(az account list --query="[?name=='${AZURE_BACKUP_SUBSCRIPTION_NAME?}'].tenantId" -o tsv) && \
AZURE_SUBSCRIPTION_ID=$(az account list --query="[?name=='${AZURE_BACKUP_SUBSCRIPTION_NAME?}'].id | [0]" -o tsv) && \
AZURE_REGION="eastus2" && \
AZURE_RESOURCE_GROUP="Velero_Backups" && \
AZURE_AKS_CLUSTER_NAME="silvios-dev-eastus2"

az account set -s ${AZURE_SUBSCRIPTION_ID?}

az group create \
  --name ${AZURE_RESOURCE_GROUP?} \
  --location ${AZURE_REGION?}

az aks create \
  --name ${AZURE_AKS_CLUSTER_NAME?} \
  --resource-group ${AZURE_RESOURCE_GROUP?} \
  --node-count 1 \
  --enable-addons monitoring \
  --generate-ssh-keys

AZURE_AKS_NODE_RESOURCE_GROUP=$(az aks show \
  --name ${AZURE_AKS_CLUSTER_NAME?} \
  --resource-group ${AZURE_RESOURCE_GROUP?} \
  --output tsv \
  --query nodeResourceGroup)

AZURE_CLIENT_SECRET=`az ad sp create-for-rbac \
  --name "velero" \
  --role "Contributor" \
  --query 'password' \
  --output tsv \
  --scopes /subscriptions/${AZURE_SUBSCRIPTION_ID?}/resourceGroups/${AZURE_RESOURCE_GROUP?} /subscriptions/${AZURE_SUBSCRIPTION_ID?}/resourceGroups/${AZURE_AKS_NODE_RESOURCE_GROUP?}`

AZURE_CLIENT_ID=`az ad sp list --display-name "velero" --query '[0].appId' -o tsv`

AZURE_STORAGE_ACCOUNT_ID="velero$(uuidgen | cut -d '-' -f5 | tr '[A-Z]' '[a-z]')"

az storage account create \
  --name ${AZURE_STORAGE_ACCOUNT_ID?} \
  --resource-group ${AZURE_RESOURCE_GROUP?} \
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

cat << EOF  > ./credentials-velero
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
AZURE_RESOURCE_GROUP=${AZURE_AKS_NODE_RESOURCE_GROUP}
AZURE_CLOUD_NAME=AzurePublicCloud
EOF

velero install \
  --provider azure \
  --plugins velero/velero-plugin-for-microsoft-azure:v1.2.0 \
  --bucket ${BLOB_CONTAINER?} \
  --secret-file ./credentials-velero \
  --use-restic \
  --backup-location-config resourceGroup=${AZURE_RESOURCE_GROUP?},storageAccount=${AZURE_STORAGE_ACCOUNT_ID?},subscriptionId=${AZURE_SUBSCRIPTION_ID?} \
  --snapshot-location-config resourceGroup=${AZURE_RESOURCE_GROUP?},subscriptionId=${AZURE_SUBSCRIPTION_ID?}

helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts

helm install velero vmware-tanzu/velero \
--create-namespace \
--namespace velero \
--set-file credentials.secretContents.cloud=./credentials-velero \
--set configuration.provider=azure \
--set configuration.backupStorageLocation.name=azure \
--set configuration.backupStorageLocation.bucket='velero' \
--set configuration.backupStorageLocation.config.resourceGroup=${AZURE_RESOURCE_GROUP?} \
--set configuration.backupStorageLocation.config.storageAccount=${AZURE_STORAGE_ACCOUNT_ID?} \
--set snapshotsEnabled=true \
--set deployRestic=true \
--set configuration.volumeSnapshotLocation.name=azure \
--set image.repository=velero/velero \
--set image.pullPolicy=Always \
--set initContainers[0].name=velero-plugin-for-microsoft-azure \
--set initContainers[0].image=velero/velero-plugin-for-microsoft-azure:master \
--set initContainers[0].volumeMounts[0].mountPath=/target \
--set initContainers[0].volumeMounts[0].name=plugins

kubectl \
  --namespace velero \
  wait deployment velero \
  --for condition=Available \
  --timeout 3600s

kubectl \
  --namespace velero \
  get pods

velero backup-location get

kubectl create namespace wp

helm install my-app bitnami/wordpress --namespace wp

velero backup create wp-backup \
  --include-namespaces wp \
  --storage-location azure \
  --wait

velero backup describe wp-backup

kubectl delete namespace wp

velero restore create --from-backup wp-backup

velero backup create vault \
  --include-namespaces vault \
  --storage-location azure \
  --wait
