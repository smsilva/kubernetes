# Ingress Traffic

This Example will show you how to configure Istio Ingress Traffic using Istio Gateway and Virtual Services.

## Setup

Run the ```setup.sh``` script:

```bash
../../setup.sh
```

## Files

### **Kubernetes**

- [serviceaccount.yaml](default-deployment/serviceaccount.yaml)
- [deployment.yaml](default-deployment/deployment.yaml)
- [service.yaml](default-deployment/service.yaml)

#### **Istio**

- [ingress-gateway.yaml](istio-objects/public-ingress-gateway.yaml)
- [virtualservice.yaml](istio-objects/demo-virtualservice.yaml)

### Deploy

```bash
kubectl create namespace demo

kubectl label namespace demo istio-injection=enabled

kubectl -n demo apply -f default-deployment/

kubectl -n demo \
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
kubectl -n demo run --image=tutum/curl curl --command -- sleep infinity

kubectl -n demo wait --for condition=Ready pod curl

kubectl -n demo exec curl -- curl \
  -is \
  -X POST  httpbin.demo.svc.cluster.local:8000/post \
  -H "Content-type: application/json" \
  -d "{ id: 1}"
```

From outside:

```bash
curl -is -X POST -H "Content-type: application/json" -d "{ id: 1}" httpbin.example.com/post
```

## Clean up

```bash
kubectl delete namespace demo
```

## Examples Index

Click [here](../../README.md) to go back to Examples Index.
