# Ingress

## Create a Kind Cluster

```bash
kind/creation
```

## NGINX Ingress Controller Install

```bash
ingress-nginx/install
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

kubectl wait pods \
  --namespace example \
  --for=condition=Ready \
  --selector app=httpbin

curl \
  --include \
  http://localhost/get

kubectl delete \
  --namespace example \
  --filename httpbin/ingress.yaml
```

## Install cert-manager

```bash
./install
```

## Create a ClusterIssuer

```bash
kubectl apply \
  --filename config/cluster-issuer.yaml
```

## Create a Selfsigned Certificate

```bash
kubectl apply \
  --namespace example \
  --filename httpbin/certificate.yaml
```

```bash
# Create an Ingress Resource
kubectl apply \
  --namespace example \
  --filename httpbin/ingress-tls-selfsigned.yaml

# Add an entry on /etc/hosts if needed
grep "echo.example.com" /etc/hosts || \
echo "127.0.0.1 echo.example.com" \
| sudo tee -a /etc/hosts

# HTTPS Test Request
curl \
  --insecure \
  --include \
  https://echo.example.com/get
```

## Cleanup

```bash
# Remove the entry from /etc/hosts
sudo sed -i '/example.com/d' /etc/hosts

# Delete Kind Cluster
kind delete cluster
```
