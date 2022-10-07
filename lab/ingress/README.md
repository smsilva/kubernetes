# Ingress

## Create a Kind Cluster

```bash
kind/creation
```

## NGINX Ingress Controller Install

```bash
nginx/install
```

## Watch resouces

```bash
watch -n 3 ./follow
```

## Deploy httpbin

Execute it from a new terminal window:

```bash
kubectl create namespace httpbin

kubectl apply \
  --namespace httpbin \
  --filename httpbin/deployment.yaml

kubectl apply \
  --namespace httpbin \
  --filename httpbin/service.yaml

kubectl \
  --namespace httpbin \
  wait deploy httpbin \
  --for=condition=Available \
  --timeout=360s
```

## Ingress for httpbin

```bash
kubectl apply \
  --namespace httpbin \
  --filename httpbin/ingress.yaml
```

## Cleanup
```bash
kind delete cluster
```
