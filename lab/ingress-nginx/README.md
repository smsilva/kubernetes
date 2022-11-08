# Ingress

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
  --set "rbac.create=true" \
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

kubectl apply \
  --namespace example \
  --filename httpbin/ingress.yaml

curl \
  --include \
  http://eks.sandbox.wasp.silvios.me/get
```
