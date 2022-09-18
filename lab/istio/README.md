# Istio

## Setup using Helm

Run the script:

```bash
./setup-istio-with-kind-and-helm
```

## Deploy httpbin

```bash
kubectl \
  apply --filename ./deployments/httpbin/namespace.yaml && \
kubectl \
  --namespace httpbin \
  apply --filename deployments/httpbin/ && \
kubectl \
  --namespace httpbin \
  wait deployment httpbin \
  --for=condition=Available \
  --timeout=360s
```

### In-cluster Test

#### From default namespace

```bash
kubectl \
  --namespace default \
  run curl \
  --image=silviosilva/utils \
  --command -- sleep infinity && \
kubectl \
  --namespace default \
  wait pod curl \
  --for condition=Ready \
  --timeout 360s

kubectl \
  --namespace default \
  exec curl -- curl \
    --include \
    --silent \
    --request GET http://httpbin.httpbin.svc:8000/get

kubectl \
  --namespace default \
  exec curl -- curl \
    --include \
    --silent \
    --request POST http://httpbin.httpbin.svc:8000/post \
    --header "Content-type: application/json" \
    --data "{ id: 1}"
```

#### From httpbin namespace

```bash
kubectl \
  --namespace httpbin \
  run curl \
  --image=silviosilva/utils \
  --command -- sleep infinity && \
kubectl \
  --namespace httpbin \
  wait pod curl \
  --for condition=Ready \
  --timeout 360s

kubectl \
  --namespace httpbin \
  exec curl -- curl \
    --include \
    --silent \
    --request GET http://httpbin:8000/get
```

### Check if the Kind Cluster NodePort is open

```bash
nc -dv 127.0.0.1 32080
```

Expected output:

```bash
Connection to 127.0.0.1 32080 port [tcp/*] succeeded!
```

### Outside Kind cluster Test

In order to enable Ingress Traffic, see the Example [Ingress Traffic](examples/traffic-management/ingress-gateway/README.md).
