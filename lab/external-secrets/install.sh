#!/bin/bash

# https://external-secrets.io/guides-getting-started/

helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets \
   external-secrets/external-secrets \
    --create-namespace \
    --namespace external-secrets

# AAD Pod Identity

# Secret Store
AZURE_KEYVAULT_URL="https://silvioswaspsandbox1.vault.azure.net"

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1alpha1
kind: SecretStore
metadata:
  name: example-secret-store
spec:
  provider:
    azurekv:
      tenantId: "${ARM_TENANT_ID}"
      vaultUrl: "${AZURE_KEYVAULT_URL}"
      authSecretRef:
        clientId:
          name: azure-secret-sp
          key: ClientID
        clientSecret:
          name: azure-secret-sp
          key: ClientSecret
EOF

ARM_CLIENT_ID_BASE64=$(echo ${ARM_CLIENT_ID} | base64)
ARM_CLIENT_SECRET_BASE64=$(echo ${ARM_CLIENT_SECRET} | base64)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: azure-secret-sp
type: Opaque
data:
  ClientID: ${ARM_CLIENT_ID_BASE64}
  ClientSecret: ${ARM_CLIENT_SECRET_BASE64}
EOF
