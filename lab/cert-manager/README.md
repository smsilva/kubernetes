# Ingress

## Create a Kind Cluster

```bash
kind/creation
```

## NGINX Ingress Controller Install for Kind

```bash
ingress-nginx-for-kind/install
```

## Deploy httpbin

```bash
kubectl create namespace example

kubectl apply \
  --namespace example \
  --filename httpbin/deployment.yaml

kubectl apply \
  --namespace example \
  --filename httpbin/service.yaml

kubectl apply \
  --namespace example \
  --filename httpbin/ingress.yaml

kubectl wait pods \
  --namespace example \
  --for=condition=Ready \
  --selector app=httpbin

curl \
  --include \
  http://localhost/get

kubectl delete \
  --namespace example \
  --filename httpbin/ingress.yaml
```

## Install cert-manager

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

## ClusterIssuers creation

```bash
kubectl apply \
  --filename config/cluster-issuers.yaml

kubectl get ClusterIssuers
```

## Create and use a Selfsigned Certificate

```bash
# Create Certificate
kubectl apply \
  --namespace example \
  --filename httpbin/certificate-selfsigned.yaml

# Create an Ingress Resource
kubectl apply \
  --namespace example \
  --filename httpbin/ingress-tls-selfsigned.yaml

# Add an entry on /etc/hosts if needed
grep "echo.example.com" /etc/hosts || \
echo "127.0.0.1 echo.example.com" \
| sudo tee -a /etc/hosts

# HTTPS Test Request
curl \
  --insecure \
  --include \
  https://echo.example.com/get
```

## Create cert-manager Let's Encrypt Staging Certificate

```bash
kubectl apply \
  --namespace example \
  --filename "config/certificate-letsencrypt-staging.yaml"

watch -n 5 'kubectl -n example get cert,pods,secret,ing'

kubectl apply \
  --namespace example \
  --filename "httpbin/ingress-tls-letsencrypt.yaml"

curl \
  --insecure \
  --include \
  https://echo.eks.sandbox.wasp.silvios.me/get
```

## Cleanup

```bash
# Remove the entry from /etc/hosts
sudo sed -i '/example.com/d' /etc/hosts

# Delete Kind Cluster
kind delete cluster
```
