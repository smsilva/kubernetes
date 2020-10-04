# Ingress Traffic

This Example will show you how to configure Istio Ingress Traffic using Istio Gateway and Virtual Services.

## Setup

Run the ```setup.sh``` script:

```bash
../setup.sh
```

## Deploy the HTTPBIN Application

First, we neeed to Deploy the Application

### Files

- [deployment.yaml](default-deployment/deployment.yaml)

### Deploy

```bash
kubectl -n demo apply -f default-deployment/
```

## Creating Istio Gateway

Then, we'll create an Ingress Gateway and VirtualService objects

```bash
kubectl -n demo apply -f istio-objects/
```

## Testing

From inside the Cluster:

```bash
kubectl -n demo run --image=tutum/curl curl --command -- sleep 5000
kubectl -n demo wait --for condition=Ready pod curl
kubectl -n demo exec curl -- curl -is -X POST -H "Content-type: application/json" -d "{ id: 1}" httpbin.demo.svc.cluster.local:8000/post
```

From outside:

```bash
curl -is -X POST -H "Content-type: application/json" -d "{ id: 1}" hhttpbin.example.com/post
```

## Clean up

```bash
kubectl delete namespace demo
```
