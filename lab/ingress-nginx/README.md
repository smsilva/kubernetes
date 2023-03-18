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
  --set "controller.service.externalTrafficPolicy=Local" \
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
```

## Test

```bash
curl \
  --include \
  --header "Host: app.example.com" \
  http://localhost:9080/get
```

## Deploy TLS Ingress

### Remove Old Ingress

```bash
kubectl delete \
  --namespace example \
  --filename httpbin/ingress.yaml
```

### Generate Self Signed Certificate

```bash
# Create Directories
CERTIFICATE_DIRECTORY="${HOME}/certificates/selfsigned/example.com"
CERTIFICATE_PRIVATE_KEY="${CERTIFICATE_DIRECTORY?}/certificate.key.pem"
CERTIFICATE_FILE="${CERTIFICATE_DIRECTORY?}/certificate.pem"

mkdir -p "${CERTIFICATE_DIRECTORY?}"

# Generate a Self Signed Certificate
openssl req \
  -x509 \
  -newkey rsa:4096 \
  -nodes \
  -keyout "${CERTIFICATE_PRIVATE_KEY?}" \
  -out "${CERTIFICATE_FILE?}" \
  -days 365 \
  -subj '/CN=app.example.com'
```

### Create a TLS Secret

```bash
kubectl \
  --namespace example \
  create secret tls \
  tls-selfsigned \
  --key "${CERTIFICATE_PRIVATE_KEY?}" \
  --cert "${CERTIFICATE_FILE?}"
```

### Create an Ingress with TLS

```bash
kubectl apply \
  --namespace example \
  --filename httpbin/ingress-tls-selfsigned.yaml
```

### Test

```bash
curl \
  --insecure \
  --include \
  --header "Host: app.example.com" \
  https://localhost:9443/get
```
