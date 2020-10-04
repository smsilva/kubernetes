# Dark Launch

## Setup

Run the ```setup.sh``` script:

```bash
../setup.sh
```

## Deploy the HTTPBIN Application

First, we neeed to Deploy the Application

### Files

- [serviceaccount.yaml](default-deployment/serviceaccount.yaml)
- [deployment-v1.yaml](default-deployment/deployment-v1.yaml) - httpbin
- [deployment-v2.yaml](default-deployment/deployment-v2.yaml) - nginx
- [service.yaml](default-deployment/service.yaml)
- [ingress-gateway.yaml](istio-objects/ingress-gateway.yaml)
- [virtualservice.yaml](istio-objects/virtualservice.yaml)
- [destinationrule.yaml](istio-objects/destinationrule.yaml)

### Deploy

```bash
kubectl -n demo apply -f default-deployment/
```

## Creating Istio Objects

Then, we'll create an Ingress Gateway and VirtualService objects

```bash
kubectl -n demo apply -f istio-objects/
```

## Testing

From inside the Cluster:

```bash
kubectl -n demo run --image=tutum/curl curl --command -- sleep 5000
kubectl -n demo wait --for condition=Ready pod curl
kubectl -n demo exec curl -- curl -is test.demo.svc.cluster.local/get | head -1 
```

### From outside

Sending without any custom Headers:

```bash
while true; do
  curl -is http://demo.example.com/get | grep \
    -E "HTTP/1.1 404 Not Found|HTTP/1.1 200 OK|nginx" && sleep 0.5; 
done
```

Sending with ```dark``` Header:

```bash
while true; do
  curl -is -H "dark: true" http://demo.example.com/get | grep \
    -E "HTTP/1.1 404 Not Found|HTTP/1.1 200 OK|nginx" && sleep 0.5; 
done
```

## Clean up

```bash
kubectl delete namespace demo
```

## Examples Index

Click [here](../README.md) to go back to Examples Index.
