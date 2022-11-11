# Istio

## Setup using Helm

Run the script:

```bash
./setup-istio-with-kind-and-helm
```

## Deploy httpbin

```bash
kubectl apply \
  --filename ./deployments/httpbin/namespace.yaml && \
kubectl apply \
  --namespace example \
  --filename deployments/httpbin/ && \
kubectl wait deployment httpbin \
  --namespace example \
  --for=condition=Available \
  --timeout=360s
```

### In-cluster Test

#### From default namespace

```bash
kubectl run curl \
  --namespace default \
  --image=silviosilva/utils \
  --command -- sleep infinity && \
kubectl wait pod curl \
  --namespace default \
  --for condition=Ready \
  --timeout 360s

kubectl \
  --namespace default \
  exec curl -- curl \
    --include \
    --silent \
    --request GET http://httpbin.example.svc:8000/get

kubectl \
  --namespace default \
  exec curl -- curl \
    --include \
    --silent \
    --request POST http://httpbin.example.svc:8000/post \
    --header "Content-type: application/json" \
    --data "{ id: 1}"
```

#### From httpbin namespace

```bash
kubectl run curl \
  --namespace example \
  --image=silviosilva/utils \
  --command -- sleep infinity && \
kubectl wait pod curl \
  --namespace example \
  --for condition=Ready \
  --timeout 360s

UUID=$(uuidgen)

kubectl \
  --namespace example \
  exec curl -- curl \
    --include \
    --silent \
    --header "x-wasp-id: ${UUID}" \
    --request GET http://httpbin:8000/get

./logs-to-json \
  --request-id ${UUID} \
  --source-namespace example \
  --source-selector run=curl \
  --target-namespace example \
  --target-selector app=httpbin
```

### From outside

```bash
kubectl apply \
  --filename ./deployments/httpbin-istio

UUID=$(uuidgen)

curl \
  --include \
  --silent \
  --header "x-wasp-id: ${UUID}" \
  --header "Host: echo.sandbox.wasp.silvios.me" \
  --request GET http://127.0.0.1:32080/get

./logs-to-json \
  --request-id ${UUID} \
  --source-namespace istio-ingress \
  --source-selector app=istio-ingress \
  --target-namespace example \
  --target-selector app=httpbin
```

## Ingress with TLS for httpbin with Selfsigned Certificate

```bash
BASE_DOMAIN="sandbox.wasp.silvios.me"
CERTIFICATE_DIRECTORY="${HOME}/certificates/config/live/${BASE_DOMAIN?}"
CERTIFICATE_PRIVATE_KEY="${CERTIFICATE_DIRECTORY?}/privkey.pem"
CERTIFICATE_FULL_CHAIN="${CERTIFICATE_DIRECTORY?}/fullchain.pem"

# Show Certificate Information
openssl x509 \
  -in "${CERTIFICATE_FULL_CHAIN?}" \
  -noout \
  -subject \
  -issuer \
  -ext subjectAltName \
  -nameopt lname \
  -nameopt sep_multiline \
  -dates

# Create a TLS Secret using the Certificate
kubectl \
  --namespace istio-ingress \
  create secret tls \
  tls-wildcard-full-chain \
  --key "${CERTIFICATE_PRIVATE_KEY?}" \
  --cert "${CERTIFICATE_FULL_CHAIN?}"

UUID=$(uuidgen)

curl \
  --include \
  --header "x-wasp-id: ${UUID}" \
  --request GET https://echo.sandbox.wasp.silvios.me:32443/get

./logs-to-json \
  --request-id ${UUID} \
  --source-namespace istio-ingress \
  --source-selector app=istio-ingress \
  --target-namespace example \
  --target-selector app=httpbin \
| tee ${HOME}/trash/istio.json && \
code ${HOME}/trash/istio.json
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

## Cleanup

```bash
kind delete cluster --name istio
```
