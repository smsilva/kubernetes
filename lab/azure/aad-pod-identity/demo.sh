#!/bin/bash

# Standard Walkthrough
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
echo "IDENTITY_NAME...........: ${IDENTITY_NAME}"

az identity create \
  -g ${IDENTITY_RESOURCE_GROUP} \
  -n ${IDENTITY_NAME}

export IDENTITY_CLIENT_ID="$(az identity show \
  -g ${IDENTITY_RESOURCE_GROUP} \
  -n ${IDENTITY_NAME} \
  --query clientId \
  --output tsv)"

export IDENTITY_RESOURCE_ID="$(az identity show \
  -g ${IDENTITY_RESOURCE_GROUP} \
  -n ${IDENTITY_NAME} \
  --query id \
  --output tsv)"

echo "IDENTITY_CLIENT_ID......: ${IDENTITY_CLIENT_ID}" && \
echo "IDENTITY_RESOURCE_ID....: ${IDENTITY_RESOURCE_ID}"

cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: ${IDENTITY_NAME}
spec:
  type: 0
  resourceID: ${IDENTITY_RESOURCE_ID}
  clientID: ${IDENTITY_CLIENT_ID}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: ${IDENTITY_NAME}-binding
spec:
  azureIdentity: ${IDENTITY_NAME}
  selector: ${IDENTITY_NAME}
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo
  labels:
    aadpodidbinding: $IDENTITY_NAME
spec:
  containers:
  - name: demo
    image: mcr.microsoft.com/oss/azure/aad-pod-identity/demo:v1.8.4
    args:
      - --subscription-id=${SUBSCRIPTION_ID}
      - --resource-group=${IDENTITY_RESOURCE_GROUP}
      - --identity-client-id=${IDENTITY_CLIENT_ID}
  nodeSelector:
    kubernetes.io/os: linux
EOF
