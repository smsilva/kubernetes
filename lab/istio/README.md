# Istio

## TL/DR Setup

Run the script below to:

- Create a Kind Cluster named "istio"

- Install 3 Helm Charts on it:
  - istio/base
  - istio/istiod
  - istio/gateway

```bash
./setup-istio-with-kind-and-helm
```

## Step by step Setup

###   Kind Cluster

```bash
# List Kind Clusters
kind get clusters

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
helm upgrade \
  --install \
  --namespace "istio-system" \
  --create-namespace \
  --version ${ISTIO_VERSION?} \
  istio-discovery istio/istiod \
  --values "./helm/istio-discovery/mesh-config.yaml" \
  --wait

# Install Istio Ingress Gateway customizing the Service with NodePorts
kubectl apply \
  --filename "./helm/istio-ingress/namespace.yaml" && \
helm upgrade \
  --install \
  --version ${ISTIO_VERSION?} \
  --namespace "istio-ingress" \
  istio-ingress istio/gateway \
  --values "./helm/istio-ingress/service.yaml"

# Show Istio Gateway POD
kubectl get pods \
  --namespace istio-ingress \
  --selector "app=istio-ingress"

# Configure Telemetry
kubectl apply \
  --filename "./deployments/telemetry.yaml"
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

###   In-cluster Test

```bash
mkdir -p ${HOME}/trash
```

####     Follow logs from httpbin pods

From another terminal:

```bash
kubectl logs \
  --namespace example \
  --selector "app=httpbin" \
  --container istio-proxy \
  --follow
```

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

###   From outside

```bash
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
  --target-selector app=httpbin \
| tee ${HOME}/trash/${UUID}.json && \
code ${HOME}/trash/${UUID}.json
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
| tee ${HOME}/trash/${UUID}.json && \
code ${HOME}/trash/${UUID}.json
```

## Commands

###   Check if the Kind Cluster NodePort is open

```bash
nc -dv 127.0.0.1 32080
```

Expected output:

```bash
Connection to 127.0.0.1 32080 port [tcp/*] succeeded!
```

###   Outside Kind cluster Test

In order to enable Ingress Traffic, see the Example [Ingress Traffic](examples/traffic-management/ingress-gateway/README.md).

###   Cleanup

```bash
kind delete cluster --name istio
```
