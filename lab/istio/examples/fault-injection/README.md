# Fault Injection

## Setup

Run the ```setup.sh``` script:

```bash
../setup.sh
```

## Deploy

### Files

#### **Kubernetes**

- [serviceaccount.yaml](default-deployment/serviceaccount.yaml)
- [deployment.yaml](default-deployment/deployment.yaml)
- [service.yaml](default-deployment/service.yaml)

#### **Istio**

- [ingress-gateway.yaml](istio-objects/ingress-gateway.yaml)
- [virtualservice-503-error.yaml](istio-objects/virtualservice-503-error.yaml)
- [virtualservice-delay.yaml](istio-objects/virtualservice-delay.yaml)

### Deploy

```bash
kubectl -n demo apply -f default-deployment/
```

## Create Istio Objects

```bash
kubectl -n demo apply -f istio-objects/
```

## Testing

### Normal

```bash
while true; do
  curl -is http://demo.example.com/get | head -1 && sleep 0.5; 
done
```

### 503 Error

```bash
while true; do
  curl -is -H "fault: 503" http://demo.example.com/get | head -1 && sleep 0.5; 
done
```

### Delay

```bash
while true; do
  curl -is -H "fault: delay" http://demo.example.com/get | head -1 && sleep 0.5; 
done
```

## Clean up

```bash
kubectl delete namespace demo
```

## Examples Index

Click [here](../README.md) to go back to Examples Index.
