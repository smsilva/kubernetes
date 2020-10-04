# Fault Injection

## Setup

Run the ```setup.sh``` script:

```bash
../setup.sh
```

## Deploy the HTTPBIN Application

First, we neeed to Deploy the Application

### Files

- [serviceaccount.yaml](default-deployment/serviceaccount.yaml)
- [deployment.yaml](default-deployment/deployment.yaml)
- [service.yaml](default-deployment/service.yaml)

### Deploy

```bash
kubectl -n demo apply -f default-deployment/
```

## Create Istio Objects

```bash
kubectl -n demo apply -f istio-objects/
```

## Testing

```bash
while true; do
  curl -is http://demo.example.com/get | head -1 && sleep 0.5; 
done
```

```bash
while true; do
  curl -is -H "fault: true" http://demo.example.com/get | head -1 && sleep 0.5; 
done
```

## Clean up

```bash
kubectl delete namespace demo
```

## Examples Index

Click [here](../README.md) to go back to Examples Index.
