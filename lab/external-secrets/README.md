# external-secrets

##  1.   Install

```bash
helm repo add external-secrets https://charts.external-secrets.io

helm repo update

helm search repo external-secrets/external-secrets

helm upgrade \
  --install \
  --namespace external-secrets \
  --create-namespace \
  external-secrets external-secrets/external-secrets \
  --wait
```

##  2.   Azure Key Vault

### 2.1. Show enviroment variables

```bash
export ARM_CLIENT_NAME="external-secrets-operator"

export ARM_CLIENT_DATA_JSON=$(az ad sp create-for-rbac \
  --name ${ARM_CLIENT_NAME?})

export ARM_CLIENT_ID=$(    jq -r '.appId'    <<< "${ARM_CLIENT_DATA_JSON?}")

export ARM_CLIENT_SECRET=$(jq -r '.password' <<< "${ARM_CLIENT_DATA_JSON?}")

cat <<EOF > /tmp/azure.conf
export ARM_TENANT_ID="${ARM_TENANT_ID}"
export ARM_CLIENT_ID="${ARM_CLIENT_ID}"
export ARM_CLIENT_NAME="${ARM_CLIENT_NAME}"
export ARM_CLIENT_SECRET="${ARM_CLIENT_SECRET}"

echo "ARM_TENANT_ID........: \${ARM_TENANT_ID}"
echo "ARM_CLIENT_ID........: \${ARM_CLIENT_ID}"
echo "ARM_CLIENT_NAME......: \${ARM_CLIENT_NAME}"
echo "ARM_CLIENT_SECRET....: \${ARM_CLIENT_SECRET:0:3}"
echo "ARM_KEYVAULT_NAME....: \${ARM_KEYVAULT_NAME}"
EOF

source /tmp/azure.conf

az keyvault set-policy \
  --name ${ARM_KEYVAULT_NAME?} \
  --spn ${ARM_CLIENT_ID?} \
  --certificate-permissions get \
  --secret-permissions get
```

### 2.2. Create a Secret with Azure Service Principal Credentials

```bash
cat <<EOF | kubectl --namespace external-secrets apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: azure-service-principal
type: Opaque
stringData:
  ARM_CLIENT_ID: ${ARM_CLIENT_ID?}
  ARM_CLIENT_SECRET: ${ARM_CLIENT_SECRET?}
EOF

kubectl get secret azure-service-principal \
  --namespace external-secrets

kubectl get secret azure-service-principal \
  --output jsonpath='{.data.ARM_CLIENT_ID}' \
  --namespace external-secrets \
| base64 --decode

kubectl get secret azure-service-principal \
  --output jsonpath='{.data.ARM_CLIENT_SECRET}' \
  --namespace external-secrets \
| base64 --decode
```

### 2.3. Create a Cluster Secret Store

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: azure
spec:
  provider:
    azurekv:
      authType: ServicePrincipal
      tenantId: ${ARM_TENANT_ID?}
      vaultUrl: https://${ARM_KEYVAULT_NAME?}.vault.azure.net

      authSecretRef:
        clientId:
          key: ARM_CLIENT_ID
          name: azure-service-principal
          namespace: external-secrets

        clientSecret:
          name: azure-service-principal
          key: ARM_CLIENT_SECRET
          namespace: external-secrets
EOF

kubectl get ClusterSecretStore
```

### 2.4. Create an ExternalSecret

```bash
kubectl create namespace example

watch -n 3 'kubectl -n example get ExternalSecret,Secret -o wide'

kubectl apply \
  --filename ./external-secret.yaml \
  --namespace example

kubectl get secret mongodb-atlas \
  --namespace example \
  --output jsonpath={.data.username} \
| base64 --decode

kubectl get secret mongodb-atlas \
  --namespace example \
  --output jsonpath={.data.password} \
| base64 --decode
```

##  3.   Cleanup

```bash
source /tmp/azure.conf

az ad sp show \
  --id ${ARM_CLIENT_ID?} \
  --query appDisplayName \
  --output tsv

az keyvault delete-policy \
  --name ${ARM_KEYVAULT_NAME?} \
  --spn ${ARM_CLIENT_ID?}

az ad sp delete \
  --id ${ARM_CLIENT_ID?}

az ad app show \
  --id ${ARM_CLIENT_ID?} \
  --query displayName \
  --output tsv

az ad app delete \
  --id ${ARM_CLIENT_ID?}

rm /tmp/azure.conf
```
