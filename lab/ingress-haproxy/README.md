# Ingress

## Create k3s Cluster

```bash
k3d cluster create \
  --api-port 6550 \
  --port "9080:80@loadbalancer" \
  --port "9443:443@loadbalancer" \
  --servers 1 \
  --k3s-arg '--disable=traefik@server:*'

kubectl wait node \
  --selector kubernetes.io/os=linux \
  --for condition=Ready

kubectl wait deployment metrics-server \
  --namespace kube-system \
  --for condition=Available \
  --timeout=360s

kubectl wait pods \
  --namespace kube-system \
  --selector k8s-app=metrics-server \
  --for condition=Ready \
  --timeout=360s
```

## Install HAProxy Ingress Controller

```bash
helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts

helm install \
  --namespace haproxy-ingress \
  --create-namespace \
  haproxy-ingress haproxy-ingress/haproxy-ingress \
  --wait
```

## Deploy httpbin

```bash
kubectl create namespace example

kubectl create deployment httpbin \
  --namespace example \
  --image silviosilva/httpbin

kubectl expose deployment httpbin \
  --namespace example \
  --port 8000 \
  --target-port 80

kubectl create ingress httpbin \
  --namespace example \
  --annotation kubernetes.io/ingress.class=haproxy \
  --rule="httpbin.127.0.0.1.nip.io/*=httpbin:8000,tls"
```

## Test

```bash
curl \
  --insecure \
  --include \
  https://httpbin.127.0.0.1.nip.io:9443/get
```
