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

kubectl -n httpbin apply -f default-deployment/

kubectl -n httpbin \
  wait \
    --for condition=Available \
    deployment httpbin
```

## Creating Istio Objects

Then, we'll create an Ingress Gateway and VirtualService objects

```bash
kubectl apply -f istio-objects/
```

## Testing

From inside the Cluster:

```bash
kubectl \
  --namespace httpbin \
  run curl \
  --image=silviosilva/utils \
  --command -- sleep infinity

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
curl -is -X POST -H "Content-type: application/json" -d "{ id: 1}" httpbin.example.com/post
```

## Clean up

```bash
kubectl delete namespace httpbin
```

## Examples Index

Click [here](../../README.md) to go back to Examples Index.
