#!/bin/bash

# https://external-secrets.io/guides-getting-started/

helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets \
   external-secrets/external-secrets \
    --create-namespace \
    --namespace external-secrets

# AAD Pod Identity

# Secret Store
cat <<EOF | tee example-secret-store.yaml
apiVersion: external-secrets.io/v1alpha1
kind: SecretStore
metadata:
  name: example-secret-store
spec:
  provider:
    azurekv:
      authType: ManagedIdentity
      tenantId: "${ARM_TENANT_ID}"
      identityId: "${IDENTITY_CLIENT_ID}"
      vaultUrl: "https://silvioswaspsandbox1.vault.azure.net"
EOF
