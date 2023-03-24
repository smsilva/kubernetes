#!/bin/bash

helm repo add external-secrets https://charts.external-secrets.io

helm repo update

helm search repo external-secrets/external-secrets

helm upgrade \
  --install \
  --namespace external-secrets \
  --create-namespace \
  external-secrets external-secrets/external-secrets \
  --repo https://charts.external-secrets.io \
  --wait

# Secret with Service Principal Credentials
cat <<EOF | kubectl --namespace external-secrets apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: azurerm-service-principal
type: Opaque
stringData:
  ARM_CLIENT_ID: ${ARM_CLIENT_ID?}
  ARM_CLIENT_SECRET: ${ARM_CLIENT_SECRET?}
EOF

# Cluster Secret Store
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1alpha1
kind: ClusterSecretStore
metadata:
  name: example-secret-store
spec:
  provider:
    azurekv:
      authType: ServicePrincipal

      tenantId: ${ARM_TENANT_ID?}
      vaultUrl: https://${ARM_KEYVAULT_NAME?}.vault.azure.net

      authSecretRef:
        clientId:
          key: ARM_CLIENT_ID
          name: azurerm-service-principal
          namespace: external-secrets

        clientSecret:
          name: azurerm-service-principal
          key: ARM_CLIENT_SECRET
          namespace: external-secrets
EOF

kubectl create namespace example

# External Secret
cat <<EOF | kubectl --namespace example apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mongodb-atlas
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: example-secret-store

  target:
    name: mongodb-atlas
    creationPolicy: Owner

  data:
    - secretKey: username
      remoteRef:
        key: secret/mongodb-atlas-user

    - secretKey: password
      remoteRef:
        key: secret/mongodb-atlas-password
EOF

kubectl --namespace example get ExternalSecret,Secret
