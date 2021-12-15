#!/bin/bash

helm upgrade \
  --install external-secrets external-secrets \
  --repo https://charts.external-secrets.io \
  --version 0.4.4 \
  --namespace external-secrets \
  --create-namespace \
  --wait

# Service Principal
ARM_CLIENT_ID_BASE64=$(     echo ${ARM_CLIENT_ID}     | base64 )
ARM_CLIENT_SECRET_BASE64=$( echo ${ARM_CLIENT_SECRET} | base64 )

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: azurerm-service-principal
  namespace: external-secrets
type: Opaque
data:
  ARM_CLIENT_ID: ${ARM_CLIENT_ID_BASE64}
  ARM_CLIENT_SECRET: ${ARM_CLIENT_SECRET_BASE64}
EOF

# Secret Store
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1alpha1
kind: ClusterSecretStore
metadata:
  name: example-secret-store
spec:
  provider:
    azurekv:
      authType: ServicePrincipal

      tenantId: ${ARM_TENANT_ID}
      vaultUrl: https://${ARM_KEYVAULT_NAME}.vault.azure.net

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

# Secret
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1alpha1
kind: ExternalSecret
metadata:
  name: docker-hub
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: azure-${ARM_KEYVAULT_NAME}

  target:
    name: docker-hub
    creationPolicy: Owner

  data:
  - secretKey: username
    remoteRef:
      key: secret/docker-hub-username

  - secretKey: password
    remoteRef:
      key: secret/docker-hub-password
EOF
