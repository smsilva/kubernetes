#    Ingress

##   1. Create an AKS Cluster

###  1.1. Create a Configuration File

```bash
cat <<EOF > /tmp/aks.conf
export AKS_CLUSTER_ID="$(uuidgen)"
export AKS_CLUSTER_ID="\${AKS_CLUSTER_ID:0:4}"
export AKS_REGION="eastus2"
export AKS_CLUSTER_NAME="wasp-sandbox-\${AKS_CLUSTER_ID?}"
export AKS_RESOURCE_GROUP_NAME="\${AKS_CLUSTER_NAME?}"
export AKS_CLUSTER_VERSION="1.24.9"
export AKS_NODE_VM_SIZE="Standard_D2_v2"
export AKS_ADMIN_GROUP_ID="d5075d0a-3704-4ed9-ad62-dc8068c7d0e1"
export AKS_DNS_PREFIX="\${AKS_CLUSTER_NAME?}"

echo "AKS_CLUSTER_ID............: \${AKS_CLUSTER_ID}"
echo "AKS_CLUSTER_NAME..........: \${AKS_CLUSTER_NAME}"
echo "AKS_RESOURCE_GROUP_NAME...: \${AKS_RESOURCE_GROUP_NAME}"
echo "AKS_DNS_PREFIX............: \${AKS_DNS_PREFIX}"
echo "AKS_CLUSTER_VERSION.......: \${AKS_CLUSTER_VERSION}"
echo "AKS_NODE_VM_SIZE..........: \${AKS_NODE_VM_SIZE}"
echo "AKS_REGION................: \${AKS_REGION}"
echo "AKS_ADMIN_GROUP_ID........: \${AKS_ADMIN_GROUP_ID}"
EOF

source /tmp/aks.conf

grep -r _REPLACE_TEMPORARY_CLUSTER_ID_HERE_ --include "*.yaml"

grep -rl _REPLACE_TEMPORARY_CLUSTER_ID_HERE_ --include "*.yaml" \
| xargs -n 1 \
    sed -i "s|_REPLACE_TEMPORARY_CLUSTER_ID_HERE_|${AKS_CLUSTER_ID}|g"
```

###  1.2. Create Azure Resources

```bash
az group create \
  --location "${AKS_REGION?}" \
  --resource-group "${AKS_RESOURCE_GROUP_NAME?}"

az aks create \
  --name "${AKS_CLUSTER_NAME?}" \
  --resource-group "${AKS_RESOURCE_GROUP_NAME?}" \
  --kubernetes-version "${AKS_CLUSTER_VERSION?}" \
  --enable-aad \
  --network-plugin azure \
  --network-policy azure \
  --aad-admin-group-object-ids "${AKS_ADMIN_GROUP_ID?}" \
  --dns-name-prefix "${AKS_DNS_PREFIX?}" \
  --enable-managed-identity \
  --enable-cluster-autoscaler \
  --node-resource-group "${AKS_RESOURCE_GROUP_NAME?}-nrg" \
  --node-vm-size "${AKS_NODE_VM_SIZE?}" \
  --node-count 1 \
  --min-count 1 \
  --max-count 5 \
  --max-pods 90

watch -n 10 ./follow_aks_creation
```

###  1.3. Get Cluster Credentials

```bash
source /tmp/aks.conf

kubectl config get-contexts

az aks get-credentials \
  --name "${AKS_CLUSTER_NAME?}" \
  --resource-group "${AKS_RESOURCE_GROUP_NAME?}" \
  --admin

kubectl config get-contexts
```

##   2. external-dns with Azure

###  2.1. Create a Secret

```bash
kubectl create namespace external-dns

cat <<EOF | kubectl --namespace external-dns apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: azure-config-file
type: Opaque
stringData:
  azure.json: |
    {
      "tenantId": "${ARM_TENANT_ID}",
      "subscriptionId": "${ARM_SUBSCRIPTION_ID}",
      "resourceGroup": "wasp-foundation",
      "useManagedIdentityExtension": true
    }
EOF

kubectl get secret azure-config-file \
  --namespace external-dns \
  --output jsonpath='{.data.azure\.json}' \
| base64 --decode
```

###  2.2. Azure Config

```bash
source /tmp/aks.conf

export DNS_ZONE_NAME="sandbox.wasp.silvios.me"
export DNS_ZONE_RESOURCE_GROUP_NAME="wasp-foundation"

export DNS_ZONE_ID=$(az network dns zone show \
  --name ${DNS_ZONE_NAME?} \
  --resource-group ${DNS_ZONE_RESOURCE_GROUP_NAME?} \
  --query "id" \
  --output tsv)

export AKS_IDENTITY_OBJECT_ID=$(az aks show \
    --name ${AKS_CLUSTER_NAME?} \
    --resource-group ${AKS_RESOURCE_GROUP_NAME?} \
    --output tsv \
    --query "identityProfile.kubeletidentity.objectId")

cat <<EOF > /tmp/dns.conf
export DNS_ZONE_ID="${DNS_ZONE_ID?}"
export DNS_ZONE_NAME="${DNS_ZONE_NAME?}"
export DNS_ZONE_RESOURCE_GROUP_NAME="${DNS_ZONE_RESOURCE_GROUP_NAME?}"
export AKS_CNAME_RECORD_VALUE="gateway.${AKS_CLUSTER_ID?}"
export AKS_CLUSTER_PUBLIC_URL=\${AKS_CNAME_RECORD_VALUE}.\${DNS_ZONE_NAME}
export AKS_IDENTITY_OBJECT_ID="${AKS_IDENTITY_OBJECT_ID?}"

echo "DNS_ZONE_ID..................: \${DNS_ZONE_ID}"
echo "DNS_ZONE_NAME................: \${DNS_ZONE_NAME}"
echo "DNS_ZONE_RESOURCE_GROUP_NAME.: \${DNS_ZONE_RESOURCE_GROUP_NAME}"
echo "AKS_CNAME_RECORD_VALUE.......: \${AKS_CNAME_RECORD_VALUE}"
echo "AKS_CLUSTER_PUBLIC_URL.......: \${AKS_CLUSTER_PUBLIC_URL}"
echo "AKS_IDENTITY_OBJECT_ID.......: \${AKS_IDENTITY_OBJECT_ID}"
EOF

source /tmp/dns.conf

az role assignment create \
  --role "Reader" \
  --assignee ${AKS_IDENTITY_OBJECT_ID?} \
  --scope ${DNS_ZONE_ID?}

az role assignment create \
  --role "Contributor" \
  --assignee ${AKS_IDENTITY_OBJECT_ID?} \
  --scope ${DNS_ZONE_ID?}
```

###  2.3. Installation

```bash
watch -n 5 'kubectl -n external-dns get pods,secrets'

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns

helm repo update external-dns

helm search repo external-dns

source /tmp/aks.conf

code ./values.yaml

helm upgrade \
  --install \
  --create-namespace \
  --namespace external-dns \
  external-dns external-dns/external-dns \
  --values "./values.yaml" \
  --wait

kubectl logs \
  --namespace external-dns \
  --selector app.kubernetes.io/instance=external-dns \
  --follow

source /tmp/dns.conf

az network dns record-set list \
  --zone-name ${DNS_ZONE_NAME} \
  --resource-group ${DNS_ZONE_RESOURCE_GROUP_NAME} \
  --output table
```

##   3. NGINX Ingress Controller

###  3.1. Installation

```bash
watch -n 5 'kubectl -n ingress-nginx get pods; echo; kubectl -n ingress-nginx get svc ingress-nginx-controller'

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update ingress-nginx

helm search repo ingress-nginx

code ./nginx/values.yaml

helm upgrade \
  --install \
  --create-namespace \
  --namespace ingress-nginx \
  ingress-nginx ingress-nginx/ingress-nginx \
  --values "./nginx/values.yaml" \
  --wait

source /tmp/dns.conf

dig @8.8.8.8 +short 
```

##   4. cert-manager

###  4.1. Installation

```bash
helm repo add jetstack https://charts.jetstack.io

helm repo update jetstack

helm search repo jetstack

helm upgrade \
  --install \
  --create-namespace \
  --namespace cert-manager \
  cert-manager jetstack/cert-manager \
  --set "installCRDs=true" \
  --wait
```

###  4.2. Setup Issuers

```bash
kubectl get ClusterIssuers

ls ./cert-manager/cluster-issuers

find ./cert-manager/cluster-issuers -type f | xargs -n 1 code

kubectl apply \
  --filename "./cert-manager/cluster-issuers"

kubectl get ClusterIssuers
```

##   5. Deploy httpbin

###  5.1. Create a Deployment and a Service

```bash
watch -n 5 'kubectl -n example get ingress,pods,certificates,secrets'

kubectl create namespace example

kubectl apply \
  --namespace example \
  --filename httpbin/deployment.yaml
```

###  5.2. Create an Ingress

```bash
kubectl apply \
  --namespace example \
  --filename httpbin/ingress.yaml

kubectl apply \
  --namespace example \
  --filename httpbin/certificate.yaml

kubectl get ingress \
  --namespace example \
  --selector type=challenge \
  --output yaml \
| kubectl neat \
| tee /tmp/ingress.yaml
code /tmp/ingress.yaml

source /tmp/dns.conf
```

##   6.Cleanup

```bash
source /tmp/aks.conf

az aks delete \
  --name "${AKS_CLUSTER_NAME?}" \
  --resource-group "${AKS_RESOURCE_GROUP_NAME?}"

az group delete \
  --resource-group "${AKS_RESOURCE_GROUP_NAME?}"
```
