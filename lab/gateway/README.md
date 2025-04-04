# Gateway API

## k3d cluster

```bash
k3d cluster create \
  --api-port 6550 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --port "32080:80@loadbalancer" \
  --port "32443:443@loadbalancer" \
  --agents 2 \
  --k3s-arg '--disable=traefik@server:*'
```

## httpbin deployment

```bash
kubectl create namespace example

kubectl config set-context --current --namespace=example

kubectl create deployment httpbin \
  --image=kennethreitz/httpbin \
  --port=80 \
  --namespace example

kubectl expose deployment httpbin \
  --name=httpbin \
  --port=80 \
  --target-port=80 \
  --namespace example

kubectl run curl \
  --image curlimages/curl \
  --command -- sleep 1d

kubectl exec curl -- curl -is httpbin/get
```

## Installation: NGINX Gateway Fabric

Reference [here](https://docs.nginx.com/nginx-gateway-fabric/installation/installing-ngf/helm/).

### Gateway API resources

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.6.2" | kubectl apply -f -
```

### Install from the OCI registry

```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --create-namespace \
  --namespace nginx-gateway && \
kubectl wait \
  --timeout=5m \
  --namespace nginx-gateway deployment/ngf-nginx-gateway-fabric \
  --for=condition=Available
```

```bash
kubectl get service \
  --namespace nginx-gateway \
  --selector app.kubernetes.io/instance=ngf

kubectl patch service ngf-nginx-gateway-fabric \
  --namespace nginx-gateway \
  --type='json' \
  --patch='[{"op": "add", "path": "/spec/ports/0/nodePort", "value": 32080}, {"op": "add", "path": "/spec/ports/1/nodePort", "value": 32443}]'
```

## Gateway API example

### TLS Secret

If you need to create a TLS secret, you can follow the steps describe [here](https://github.com/smsilva/kubernetes/tree/main/lab/ingress/certbot).

```bash
kubectl create secret tls tls-wasp-silvios-me \
  --namespace example \
  --key "${certificate_private_key?}" \
  --cert "${certificate_full_chain?}"
```

### Gateway resources

```bash
kubectl apply -f config.yaml
```

### Test

```bash
sudo sed -i '/wasp.silvios.me/d' /etc/hosts

cat <<EOF | sudo tee -a /etc/hosts
127.0.0.1 echo.wasp.silvios.me
127.0.0.1 api.wasp.silvios.me
EOF
```

```bash
curl -ik https://echo.wasp.silvios.me:32443/get
```
