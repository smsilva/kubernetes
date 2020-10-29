# Egress TLS Origination

## Deploy Sleep Container

```bash
kubectl label namespace default istio-injection=enabled

kubectl -n default apply -f ${ISTIO_BASE_DIR}/samples/sleep/sleep.yaml

kubectl -n default wait pod -l app=sleep --for condition=Ready
```

## Files

### **Istio**

- [service-entry.yaml](istio-objects/service-entry.yaml)
- [virtual-service.yaml](istio-objects/virtual-service.yaml)
- [destination-rule.yaml](istio-objects/destination-rule.yaml)

## Test

```bash
export SOURCE_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})

kubectl exec "${SOURCE_POD}" -c sleep -- curl -sL -o /dev/null -D - http://edition.cnn.com/politics
```

### Creating Istio Objects

```bash
kubectl -n default apply -f istio-objects/
```

### Testing

```bash
kubectl exec "${SOURCE_POD}" -c sleep -- curl -sL -o /dev/null -D - http://edition.cnn.com/politics
kubectl exec "${SOURCE_POD}" -c sleep -- curl -sL -o /dev/null -D - https://edition.cnn.com/politics
```

## Clean up

```bash
kubectl -n default delete -f istio-objects/
kubectl -n default delete -f ${ISTIO_BASE_DIR}/samples/sleep/sleep.yaml
```

## Examples Index

Click [here](../../README.md) to go back to Examples Index.
