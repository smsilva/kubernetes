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
  --timeout=360s; sleep 2

kubectl wait pods \
  --namespace kube-system \
  --selector k8s-app=metrics-server \
  --for condition=Ready \
  --timeout=360s
```

## NGINX Ingress Controller Install

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
  --wait
```

## cert-manager Install

```bash
helm repo add jetstack https://charts.jetstack.io

helm repo update jetstack

helm search repo jetstack

helm upgrade \
  --install \
  --create-namespace \
  --namespace cert-manager \
  cert-manager jetstack/cert-manager \
  --set "installCRDs=true" \
  --wait
```

## cert-manager ClusterIssuers creation

```bash
kubectl apply \
  --filename config/cluster-issuer-self-signed.yaml

kubectl get ClusterIssuer
```

## Deploy httpbin

```bash
watch -n 3 'kubectl -n example get pods,certificate,secret,ingress'

kubectl create namespace example

kubectl config set-context \
  --current \
  --namespace example

kubectl apply \
  --namespace example \
  --filename httpbin/deployment.yaml

kubectl apply \
  --namespace example \
  --filename httpbin/service.yaml

kubectl wait pods \
  --namespace example \
  --for=condition=Ready \
  --selector app=httpbin
```

## Create Certificate first

```bash
# Create Certificate
kubectl apply \
  --namespace example \
  --filename resources/certificate-first/certificate.yaml

# Create an Ingress Resource
kubectl apply \
  --namespace example \
  --filename resources/certificate-first/ingress.yaml

# Add an entry on /etc/hosts if needed
grep "app.example.com" /etc/hosts || \
echo "127.0.0.1 app.example.com" \
| sudo tee -a /etc/hosts

# HTTPS Test Request
curl \
  --insecure \
  --include \
  https://app.example.com:9443/get

# Check Certificate with kubectl
kubectl get secret app-example-com-self-signed \
  --namespace example \
  --output jsonpath='{.data.tls\.crt}' \
| base64 -d \
| openssl x509 -noout -text \
| less

# Check Certificate used
echo \
| openssl s_client --connect app.example.com:9443 \
| openssl x509 -noout -text \
| less

# Remove Certificate and Ingress
kubectl delete \
  --namespace example \
  --filename resources/certificate-first/

kubectl delete secret app-example-com-self-signed \
  --namespace example
```

## Create cert-manager Certificate from Ingress

```bash
kubectl apply \
  --namespace example \
  --filename "resources/ingress/ingress.yaml"

# HTTPS Test Request
curl \
  --insecure \
  --include \
  https://app.example.com:9443/get

# Check Certificate with kubectl
kubectl get secret app-example-com-self-signed-ingress \
  --namespace example \
  --output jsonpath='{.data.tls\.crt}' \
| base64 -d \
| openssl x509 -noout -text \
| less

# Check Certificate used
echo \
| openssl s_client --connect app.example.com:9443 \
| openssl x509 -noout -text \
| less
```
