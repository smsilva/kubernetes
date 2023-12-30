# k3d

## Create Cluster

```bash
k3d cluster create \
  --api-port 6550 \
  --port "9080:80@loadbalancer" \
  --port "9443:443@loadbalancer" \
  --servers 1 \
  --agents 2 \
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

## Install Istio

```bash
ISTIO_VERSION="${ISTIO_VERSION-1.20.1}"

helm repo add istio https://istio-release.storage.googleapis.com/charts

helm repo update istio

helm search repo \
  --regexp "istio/istiod|istio/base|istio/gateway" \
  --version ${ISTIO_VERSION?}

helm install \
  istio-base istio/base \
  --namespace istio-system \
  --create-namespace \
  --wait

helm install \
  istio-control-plane istio/istiod \
  --namespace istio-system \
  --wait

kubectl create namespace istio-ingress

kubectl label namespace istio-ingress istio-injection=enabled

helm install \
  istio-ingressgateway istio/gateway \
  --namespace istio-ingress \
  --wait
```

## Deployment

```bash
kubectl apply -f ./deploy/httpbin/namespace.yaml

kubectl \
  --namespace example \
  apply -f ./deploy/httpbin/

kubectl \
  --namespace example \
  apply -f ./deploy/httpbin-istio

kubectl wait deployment httpbin \
  --namespace example \
  --for condition=Available \
  --timeout=360s
```

## Test

```bash
curl \
  --include \
  --silent \
  --header "Host: app.example.com" \
  --request GET http://127.0.0.1:9080/get
```

## Cleanup

```bash
k3d cluster delete
```
