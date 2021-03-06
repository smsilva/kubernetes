#!/bin/bash

AZ_APP_GATEWAY_NAME="app-gateway-aks" && \
AZ_PUBLIC_IP_DNS_PREFIX="silvios-dev" && \
AZ_PUBLIC_IP_NAME="${AZ_APP_GATEWAY_NAME?}-public-ip" && \
AZ_APP_GATEWAY_VNET_NAME="${AZ_APP_GATEWAY_NAME?}-vnet" && \
AZ_APP_GATEWAY_SUBNET_NAME="${AZ_APP_GATEWAY_NAME?}-subnet"

# Deploy a new Application Gateway
# https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing#deploy-a-new-application-gateway

az network public-ip create \
  --name ${AZ_PUBLIC_IP_NAME?} \
  --resource-group ${AZ_AKS_RESOURCE_GROUP_NAME?} \
  --dns-name "${AZ_PUBLIC_IP_DNS_PREFIX?}" \
  --allocation-method Static \
  --sku Standard

az network vnet create \
  --name ${AZ_APP_GATEWAY_VNET_NAME?} \
  --resource-group ${AZ_AKS_RESOURCE_GROUP_NAME?} \
  --address-prefix 11.0.0.0/8 \
  --subnet-name ${AZ_APP_GATEWAY_SUBNET_NAME?} \
  --subnet-prefix 11.1.0.0/16
 
az network application-gateway create \
  --name ${AZ_APP_GATEWAY_NAME?} \
  --location ${AZ_AKS_REGION?} \
  --resource-group ${AZ_AKS_RESOURCE_GROUP_NAME?} \
  --sku Standard_v2 \
  --public-ip-address ${AZ_PUBLIC_IP_NAME?} \
  --vnet-name ${AZ_APP_GATEWAY_VNET_NAME?} \
  --subnet ${AZ_APP_GATEWAY_SUBNET_NAME?}

# Enable the AGIC add-on in existing AKS cluster through Azure CLI
# https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing#enable-the-agic-add-on-in-existing-aks-cluster-through-azure-cli

appgwId=$(az network application-gateway show \
  --name ${AZ_APP_GATEWAY_NAME?} \
  --resource-group ${AZ_AKS_RESOURCE_GROUP_NAME?} \
  --output tsv \
  --query "id") 

az aks enable-addons \
  --name ${AZ_AKS_CLUSTER_NAME?} \
  --resource-group ${AZ_AKS_RESOURCE_GROUP_NAME?} \
  --addons ingress-appgw \
  --appgw-id ${appgwId?}

# Peer the two virtual networks together
# https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing#peer-the-two-virtual-networks-together

nodeResourceGroup=$(az aks show \
  --name ${AZ_AKS_CLUSTER_NAME?} \
  --resource-group ${AZ_AKS_RESOURCE_GROUP_NAME?} \
  --output tsv \
  --query "nodeResourceGroup")

aksVnetName=$(az network vnet list \
  --resource-group ${nodeResourceGroup?} \
  --output tsv \
  --query "[0].name")

aksVnetId=$(az network vnet show \
  --name ${aksVnetName?} \
  --resource-group ${nodeResourceGroup?} \
  --output tsv \
  --query "id")

az network vnet peering create \
  --name AppGWtoAKSVnetPeering \
  --resource-group ${AZ_AKS_RESOURCE_GROUP_NAME?} \
  --vnet-name ${AZ_APP_GATEWAY_VNET_NAME?} \
  --remote-vnet ${aksVnetId?} \
  --allow-vnet-access

appGWVnetId=$(az network vnet show \
  --name ${AZ_APP_GATEWAY_VNET_NAME?} \
  --resource-group ${AZ_AKS_RESOURCE_GROUP_NAME?} \
  --output tsv \
  --query "id")

az network vnet peering create \
  --name AKStoAppGWVnetPeering \
  --resource-group ${nodeResourceGroup?} \
  --vnet-name ${aksVnetName?} \
  --remote-vnet ${appGWVnetId?} \
  --allow-vnet-access

# Role Assignment

AZ_SUBSCRIPTION_ID="ddc30188-075a-470d-a6ca-05a1987c51a3"
AZ_APP_GATEWAY_MANAGED_IDENTITY_CLIENT_ID="0cbda7c2-e930-4342-9346-a41b211fb0d4"

az role assignment create \
  --role Reader \
  --scope /subscriptions/${AZ_SUBSCRIPTION_ID?}/resourceGroups/${AZ_AKS_RESOURCE_GROUP_NAME?} \
  --assignee ${AZ_APP_GATEWAY_MANAGED_IDENTITY_CLIENT_ID?}
  
az role assignment create \
  --role Contributor \
  --scope /subscriptions/${AZ_SUBSCRIPTION_ID?}/resourceGroups/${AZ_AKS_RESOURCE_GROUP_NAME?}/providers/Microsoft.Network/applicationGateways/${AZ_APP_GATEWAY_NAME?} \
  --assignee ${AZ_APP_GATEWAY_MANAGED_IDENTITY_CLIENT_ID?}
