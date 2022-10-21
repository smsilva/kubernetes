# Ingress

## Install

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

kubectl wait \
  --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

docker network inspect -f '{{.IPAM.Config}}' kind

kubectl apply -f config.yaml
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
