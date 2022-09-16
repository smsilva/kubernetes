# Istio

## Setup using Helm

Run the script:

```bash
./setup-istio-with-kind-and-helm
```

## Deploy httpbin

```bash
kubectl apply -f ./deployments/httpbin/namespace.yaml > /dev/null

kubectl \
  --namespace httpbin \
  apply -f deployments/httpbin/ && \
kubectl \
  --namespace httpbin \
  wait deployment httpbin \
  --for=condition=Available \
  --timeout=360s > /dev/null
```

### In-cluster Test

#### From default namespace

```bash
kubectl \
  --namespace default \
  run utils \
  -it \
  --rm \
  --image=silviosilva/utils

curl -i http://httpbin.httpbin.svc:8000/get
```

#### From httpbin namespace
```bash
kubectl \
  --namespace httpbin \
  run utils \
  -it \
  --rm \
  --image=silviosilva/utils

curl -i http://httpbin:8000/get
```

### Outside Kind cluster Test

```bash
curl -i -H 'host: demo.example.com' http://127.0.0.1:32080/get
```
