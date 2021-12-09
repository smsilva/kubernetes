#!/bin/bash

# https://azure.github.io/aad-pod-identity/docs/

# To install/upgrade AAD Pod Identity on RBAC-enabled clusters:
kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/v1.8.4/deploy/infra/deployment-rbac.yaml

# For AKS clusters, you will have to allow MIC and AKS add-ons to access IMDS without being intercepted by NMI:
kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/v1.8.4/deploy/infra/mic-exception.yaml

helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts

helm install aad-pod-identity aad-pod-identity/aad-pod-identity

# Demo
https://azure.github.io/aad-pod-identity/docs/demo/

# https://azure.github.io/aad-pod-identity/docs/demo/standard_walkthrough/

export SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
export RESOURCE_GROUP="wasp-aks-blue"
export CLUSTER_NAME="wasp-aks-blue-94v"

# for this demo, we will be deploying a user-assigned identity to the AKS node resource group
export IDENTITY_RESOURCE_GROUP="$(az aks show \
  -g ${RESOURCE_GROUP} \
  -n ${CLUSTER_NAME} \
  --query nodeResourceGroup \
  --output tsv)"

export IDENTITY_NAME="demo"

echo "SUBSCRIPTION_ID.........: ${SUBSCRIPTION_ID}" && \
echo "RESOURCE_GROUP..........: ${RESOURCE_GROUP}" && \
echo "CLUSTER_NAME............: ${CLUSTER_NAME}" && \
echo "IDENTITY_RESOURCE_GROUP.: ${IDENTITY_RESOURCE_GROUP}" && \
echo "IDENTITY_NAME...........: ${IDENTITY_NAME}" && \
