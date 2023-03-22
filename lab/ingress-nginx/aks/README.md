#    Ingress

##   1. Create an AKS Cluster

###  1.1. Create a Configuration File

```bash
cat <<EOF > /tmp/aks.conf
export AZ_AKS_CLUSTER_ID="$(uuidgen)"
export AZ_AKS_CLUSTER_ID="\${AZ_AKS_CLUSTER_ID:0:4}"
export AZ_AKS_REGION="eastus2"
export AZ_AKS_CLUSTER_NAME="wasp-sandbox-\${AZ_AKS_CLUSTER_ID?}"
export AZ_AKS_RESOURCE_GROUP_NAME="\${AZ_AKS_CLUSTER_NAME?}"
export AZ_AKS_CLUSTER_VERSION="1.24.9"
export AZ_AKS_NODE_VM_SIZE="Standard_D2_v2"
export AZ_AKS_ADMIN_GROUP_ID="d5075d0a-3704-4ed9-ad62-dc8068c7d0e1"
export AZ_AKS_DNS_PREFIX="\${AZ_AKS_CLUSTER_NAME?}"

echo "AZ_AKS_CLUSTER_ID............: \${AZ_AKS_CLUSTER_ID}"
echo "AZ_AKS_CLUSTER_NAME..........: \${AZ_AKS_CLUSTER_NAME}"
echo "AZ_AKS_RESOURCE_GROUP_NAME...: \${AZ_AKS_RESOURCE_GROUP_NAME}"
echo "AZ_AKS_DNS_PREFIX............: \${AZ_AKS_DNS_PREFIX}"
echo "AZ_AKS_CLUSTER_VERSION.......: \${AZ_AKS_CLUSTER_VERSION}"
echo "AZ_AKS_NODE_VM_SIZE..........: \${AZ_AKS_NODE_VM_SIZE}"
echo "AZ_AKS_REGION................: \${AZ_AKS_REGION}"
echo "AZ_AKS_ADMIN_GROUP_ID........: \${AZ_AKS_ADMIN_GROUP_ID}"
EOF

source /tmp/aks.conf
```

###  1.2. Create Azure Resources

```bash
# Load Parameters
source /tmp/aks.conf

# Resource Group
az group create \
  --location "${AZ_AKS_REGION?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}"

# AKS Cluster
az aks create \
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}" \
  --kubernetes-version "${AZ_AKS_CLUSTER_VERSION?}" \
  --enable-aad \
  --network-plugin azure \
  --network-policy azure \
  --aad-admin-group-object-ids "${AZ_AKS_ADMIN_GROUP_ID?}" \
  --dns-name-prefix "${AZ_AKS_DNS_PREFIX?}" \
  --enable-managed-identity \
  --enable-cluster-autoscaler \
  --node-resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}-nrg" \
  --node-vm-size "${AZ_AKS_NODE_VM_SIZE?}" \
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
  --name "${AZ_AKS_CLUSTER_NAME?}" \
  --resource-group "${AZ_AKS_RESOURCE_GROUP_NAME?}" \
  --admin

kubectl config get-contexts
```

##   2. NGINX Ingress Controller

###  2.1. Installation

```bash
watch -n 5 'kubectl -n ingress-nginx get svc ingress-nginx-controller'

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update ingress-nginx

helm search repo ingress-nginx

cat ./nginx/values.yaml

helm upgrade \
  --install \
  --create-namespace \
  --namespace ingress-nginx \
  ingress-nginx ingress-nginx/ingress-nginx \
  --values "./nginx/values.yaml" \
  --wait
```

##   3. Update DNS Zone

```bash
source /tmp/aks.conf

cat <<EOF > /tmp/dns.conf
DNS_CNAME_RECORD_VALUE="gateway.${AZ_AKS_CLUSTER_ID?}"
DNS_ZONE_NAME="sandbox.wasp.silvios.me"
DNS_ZONE_RESOURCE_GROUP_NAME="wasp-foundation"
AZ_AKS_CLUSTER_PUBLIC_URL=\${DNS_CNAME_RECORD_VALUE}.\${DNS_ZONE_NAME}
AZ_AKS_CLUSTER_PUBLIC_IP="$(kubectl get svc ingress-nginx-controller \
  --namespace ingress-nginx \
  --output jsonpath='{.status.loadBalancer.ingress[0].ip}')"

echo "DNS_CNAME_RECORD_VALUE.......: \${DNS_CNAME_RECORD_VALUE}"
echo "DNS_ZONE_NAME................: \${DNS_ZONE_NAME}"
echo "DNS_ZONE_RESOURCE_GROUP_NAME.: \${DNS_ZONE_NAME}"
echo "AZ_AKS_CLUSTER_PUBLIC_IP.....: \${AZ_AKS_CLUSTER_PUBLIC_IP}"
echo "AZ_AKS_CLUSTER_PUBLIC_URL....: \${AZ_AKS_CLUSTER_PUBLIC_URL}"
EOF

source /tmp/dns.conf

dig @8.8.8.8 +short ${AZ_AKS_CLUSTER_PUBLIC_URL?}

az network dns record-set a \
  add-record \
    --zone-name "${DNS_ZONE_NAME?}" \
    --resource-group "${DNS_ZONE_RESOURCE_GROUP_NAME?}" \
    --record-set-name "${DNS_CNAME_RECORD_VALUE?}" \
    --ipv4-address "${AZ_AKS_CLUSTER_PUBLIC_IP?}" \
    --ttl 60 \
    --if-none-match
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
ls ./cert-manager/cluster-issuers

cat ./cert-manager/cluster-issuers/letsencrypt-production.yaml

cat ./cert-manager/cluster-issuers/letsencrypt-staging.yaml

kubectl apply \
  --filename "./cert-manager/cluster-issuers"

kubectl get ClusterIssuers
```

##   5. Deploy httpbin

###  5.1. Create a Deployment and a Service

```bash
kubectl create namespace example

kubectl apply \
  --namespace example \
  --filename httpbin/deployment.yaml
```

###  5.2. Create an Ingress

```bash
watch -n 5 'kubectl -n example get certificates,ingress,pods,certificaterequest,secrets'

kubectl apply \
  --namespace example \
  --filename httpbin/ingress.yaml
```

###  5.3. Check

```bash
source /tmp/dns.conf

curl \
  --insecure \
  --include \
  https://${AZ_AKS_CLUSTER_PUBLIC_URL?}/httpbin/get
```
