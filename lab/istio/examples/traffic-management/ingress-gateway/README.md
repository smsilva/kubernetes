# Ingress Traffic

This Example will show you how to configure Istio Ingress Traffic using Istio Gateway and Virtual Services.

## Setup

Run the [setup](../../../setup-istio-with-kind-and-helm) script:

```bash
../../../setup-istio-with-kind-and-helm
```

## Files

### **Kubernetes**

- [serviceaccount.yaml](default-deployment/serviceaccount.yaml)
- [deployment.yaml](default-deployment/deployment.yaml)
- [service.yaml](default-deployment/service.yaml)

#### **Istio**

- [public-ingress-gateway.yaml](istio-objects/public-ingress-gateway.yaml)
- [virtualservice-routes-mesh.yaml](istio-objects/virtualservice-routes-mesh.yaml)
- [virtualservice-routes-public.yaml](istio-objects/virtualservice-routes-public.yaml)

### Deploy

```bash
kubectl create namespace httpbin

kubectl label namespace httpbin istio-injection=enabled

kubectl \
  --namespace httpbin \
  apply --filename default-deployment/

kubectl \
  --namespace httpbin \
  wait deployment httpbin \
    --for condition=Available
```

## Creating Istio Objects


### **Ingress Gateway** and **VirtualService**

```bash
kubectl apply --filename istio-objects/
```

### Kubernetes Default **Ingress**

```bash
kubectl apply --filename kubernetes-ingress-only/
```

## Testing

From inside the Cluster:

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
    --request POST httpbin.httpbin.svc.cluster.local:8000/post \
    --header "Content-type: application/json" \
    --data "{ id: 1}"
```

From outside:

```bash
curl \
  --include \
  --request GET \
  --header "host: httpbin.example.com" \
  127.0.0.1:32080/get

curl \
  --include \
  --request POST \
  --header "Content-type: application/json" \
  --header "host: httpbin.example.com" \
  --data "{ id: 1}" 127.0.0.1:32080/post
```

## Clean up

```bash
kubectl delete namespace httpbin
```

## Examples Index

Click [here](../../README.md) to go back to Examples Index.
