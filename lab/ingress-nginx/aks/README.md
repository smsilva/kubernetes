# Ingress

## Create AKS Cluster

## Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update ingress-nginx

helm search repo ingress-nginx

helm upgrade \
  --install \
  --create-namespace \
  --namespace ingress-nginx \
  ingress-nginx ingress-nginx/ingress-nginx \
  --values "./values.yaml" \
  --wait
```

## cert-manager Install

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

## Deploy httpbin

```bash
kubectl create namespace example

kubectl apply \
  --namespace example \
  --filename httpbin/deployment.yaml

kubectl apply \
  --namespace example \
  --filename httpbin/service.yaml
```

## Create ClusterIssuers

```bash
kubectl apply \
  --filename "./cluster-issuers.yaml"
```

## Create Ingress

```bash
kubectl apply \
  --namespace example \
  --filename httpbin/ingress.yaml
```
