# AKS

## Configuration

```bash
az login

az account list -o table

az account set --name wasp-sandbox
```

## List Available AKS Versions

```bash
az aks get-versions -o table -l eastus2
```

## Creation

```bash
AZ_AKS_REGION="eastus2"
AZ_AKS_RESOURCE_GROUP_NAME="wasp-sandbox"
AZ_AKS_CLUSTER_VERSION="1.24.9"
AZ_AKS_NODE_VM_SIZE="Standard_D2_v2"
AZ_AKS_CLUSTER_NAME="wasp-sandbox"
AZ_AKS_ADMIN_GROUP_ID="d5075d0a-3704-4ed9-ad62-dc8068c7d0e1"
AZ_AKS_DNS_PREFIX="${AZ_AKS_CLUSTER_NAME?}"

az group create \
  --location "${AZ_AKS_REGION?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"

az aks create \
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}" \
  --kubernetes-version "${AZ_AKS_CLUSTER_VERSION?}" \
  --enable-aad \
  --network-plugin azure \
  --network-policy azure \
  --aad-admin-group-object-ids "${AZ_AKS_ADMIN_GROUP_ID?}" \
  --dns-name-prefix "${AZ_AKS_DNS_PREFIX?}" \
  --enable-managed-identity \
  --enable-cluster-autoscaler \
  --node-vm-size "${AZ_AKS_NODE_VM_SIZE?}" \
  --node-count 1 \
  --min-count 1 \
  --max-count 5 \
  --max-pods 100
```
## Get Credentials

```bash
az aks get-credentials \
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}" \
  --admin
```

## Cleanup

```bash
az aks delete \
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"

az group delete \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"
```
