# Istio

## TL/DR Setup

Run the script below to:

- Create a Kind Cluster named "istio"

- Install 3 Helm Charts on it:
  - istio/base
  - istio/istiod
  - istio/gateway

- Deploy httpbin
  - namespace: example
  - deployment: httpbin
  - service: httpbin.example.svc:8000
  - gateway: httpbin
  - virtual-service:
    - httpbin-mesh
    - httpbin-public

- Start to follow istio-proxy logs for httbin pods

```bash
./tl-dr-run
```

## Step by step Setup

###   Kind Cluster

```bash
# Create Kind Cluster with Extra Ports exposed (32080 and 32443)
kind create cluster \
  --image kindest/node:v1.24.0 \
  --config "./kind/cluster.yaml" \
  --name istio
```

###   Install using Helm Charts

```bash
# Configure Helm Repo
ISTIO_VERSION="${ISTIO_VERSION-1.16.0}"

helm repo add istio https://istio-release.storage.googleapis.com/charts

helm repo update istio

helm search repo \
  --regexp "istio/istiod|istio/base|istio/gateway" \
  --version ${ISTIO_VERSION?}

# Install istio-base (CRDs)
helm install \
  --namespace "istio-system" \
  --create-namespace \
  istio-base istio/base \
  --version ${ISTIO_VERSION?} \
  --wait

# Install Istio Discovery (istiod) - Logs in JSON format
helm install \
  --namespace "istio-system" \
  --version ${ISTIO_VERSION?} \
  istio-discovery istio/istiod \
  --values "./helm/istio-discovery/mesh-config.yaml" \
  --values "./helm/istio-discovery/telemetry.yaml" \
  --wait

# Install Istio Ingress Gateway customizing the Service with NodePorts
kubectl apply \
  --filename "./helm/istio-ingress/namespace.yaml" && \
helm install \
  --namespace "istio-ingress" \
  --version ${ISTIO_VERSION?} \
  istio-ingress istio/gateway \
  --values "./helm/istio-ingress/service.yaml"

# Show Istio Gateway POD
kubectl get pods \
  --namespace istio-ingress \
  --selector "app=istio-ingress"
```

###   Download Istio Repositories with Examples

```bash
# Download the Latest Istio Repository
./scripts/istio-latest-repo-download.sh

# Add this line to your ${HOME}/.bashrc file
[ -f ~/.bash_config ] && source ~/.bash_config

# Source your ${HOME}/.bashrc file
source ${HOME}/.bashrc

# Configuring Add-ons
kubectl apply -f "${ISTIO_BASE_DIR?}/samples/addons/prometheus.yaml"
kubectl apply -f "${ISTIO_BASE_DIR?}/samples/addons/kiali.yaml"
```

## Deploy httpbin and curl pods

###   deploy

```bash
# Example namespace and httpbin Deployment
kubectl apply \
  --filename "./deployments/httpbin/namespace.yaml" && \
kubectl apply \
  --namespace example \
  --filename "deployments/httpbin/" && \
kubectl apply \
  --namespace example \
  --filename "./deployments/httpbin-istio"

# curl pod on default namespace
kubectl run curl \
  --namespace default \
  --image=silviosilva/utils \
  --command -- sleep infinity

# curl pod on example namespace
kubectl run curl \
  --namespace example \
  --image=silviosilva/utils \
  --command -- sleep infinity
```

###   Wait

```bash
# Wait for httpbin deploy becomes Available
kubectl wait deployment httpbin \
  --namespace example \
  --for condition=Available \
  --timeout=360s

# Wait for curl pod become Ready
kubectl wait pod curl \
  --namespace default \
  --for condition=Ready \
  --timeout 360s

# Wait for curl pod become Ready
kubectl wait pod curl \
  --namespace example \
  --for condition=Ready \
  --timeout 360s
```

## Tests

###   Follow logs from httpbin pods

From another terminal:

```bash
kubectl logs \
  --namespace example \
  --selector "app=httpbin" \
  --container istio-proxy \
  --follow
```

###   In-cluster

####     From default namespace

```bash
UUID=$(uuidgen)

kubectl \
  --namespace default \
  exec curl -- curl \
    --include \
    --silent \
    --header "x-wasp-id: ${UUID}" \
    --request GET http://httpbin.example.svc:8000/get

./logs-to-json \
  --request-id ${UUID} \
  --target-namespace example \
  --target-selector app=httpbin \
| tee ${HOME}/trash/${UUID}.json && \
code ${HOME}/trash/${UUID}.json
```

####     From example namespace

```bash
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
  --target-selector app=httpbin \
| tee ${HOME}/trash/${UUID}.json && \
code ${HOME}/trash/${UUID}.json
```

###   Prometheus Metrics

```bash
watch -n 3 '
  kubectl \
    --namespace example \
    exec curl -- curl \
      --silent \
      --request GET http://localhost:15020/stats/prometheus \
  | egrep "^istio_requests_total"'

watch -n 3 '
  kubectl \
    --namespace example \
    exec curl -- curl \
      --silent \
      --request GET http://10.244.3.3:15020/stats/prometheus \
  | egrep "^istio_request_bytes_count|^istio_requests_total|^istio_request_duration_milliseconds_sum"'
```

###   Outside

```bash
UUID=$(uuidgen)

curl \
  --include \
  --silent \
  --header "x-wasp-id: ${UUID}" \
  --header "Host: app.example.com" \
  --request GET http://127.0.0.1:32082/get

./logs-to-json \
  --request-id ${UUID} \
  --source-namespace istio-ingress \
  --source-selector app=istio-ingress \
  --target-namespace example \
  --target-selector app=httpbin \
| tee ${HOME}/trash/${UUID}.json && \
code ${HOME}/trash/${UUID}.json
```

###   Load Test

```bash
wrk \
  --header "User-Agent: wrk" \
  --header "Host: app.example.com" \
  --threads 12 \
  --connections 400 \
  --duration 60s \
  --latency \
  http://127.0.0.1:32082/get
```

###   Generate Traffic

```bash
# Generate Traffic for httpbin Deployment 200 from outside
watch -n 3 'curl \
  --include \
  --silent \
  --header "x-wasp-id: $(uuidgen)" \
  --header "Host: app.example.com" \
  --request GET http://127.0.0.1:32082/get'

# Generate Traffic for httpbin Deployment 200 from example namespace
watch -n 3 'kubectl \
  --namespace example \
  exec curl -- curl \
    --include \
    --silent \
    --header "x-wasp-id: $(uuidgen)" \
    --request GET http://httpbin:8000/get'

# Generate Traffic for httpbin Deployment 503
watch -n 30 'curl \
  --include \
  --silent \
  --header "x-wasp-id: $(uuidgen)" \
  --header "Host: app.example.com" \
  --request GET http://127.0.0.1:32082/status/503'
```

## Ingress

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
  --request GET "https://echo.${BASE_DOMAIN?}:32443/get"

./logs-to-json \
  --request-id ${UUID} \
  --source-namespace istio-ingress \
  --source-selector app=istio-ingress \
  --target-namespace example \
  --target-selector app=httpbin \
| tee ${HOME}/trash/${UUID}.json && \
code ${HOME}/trash/${UUID}.json
```

## Commands

###   Check if the Kind Cluster NodePort is open

```bash
nc -dv 127.0.0.1 32082
```

Expected output:

```bash
Connection to 127.0.0.1 32082 port [tcp/*] succeeded!
```

## Cleanup

```bash
kind delete cluster --name istio
```
