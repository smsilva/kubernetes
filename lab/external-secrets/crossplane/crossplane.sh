#!/bin/bash

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1alpha1
kind: SecretStore
metadata:
  name: azurerm
spec:
  provider:
    azurekv:
      tenantId: "${ARM_TENANT_ID}"
      vaultUrl: "https://${ARM_KEYVAULT_NAME}.vault.azure.net"
     
      authSecretRef:
        clientId:
          name: azurerm-credentials
          key:  ARM_CLIENT_ID

        clientSecret:
          name: azurerm-credentials
          key:  ARM_CLIENT_SECRET
EOF

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1alpha1
kind: ExternalSecret
metadata:
  name: docker-hub
spec:
  refreshInterval: 1h

  secretStoreRef:
    kind: SecretStore
    name: azurerm

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
