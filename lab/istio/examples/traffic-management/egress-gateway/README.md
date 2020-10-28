# Egress gateway for HTTPS traffic

## Setup

### IstioOperator to Restrict Outbound Traffic

```bash
kubectl -n istio-system apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-operator
  namespace: istio-system
spec:
  profile: default
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
  components:
    ingressGateways:
    - name: istio-ingressgateway
      namespace: istio-system
      enabled: true
    egressGateways:
    - name: istio-egressgateway
      namespace: istio-system
      enabled: true
  values:
    global:
      proxy:
        autoInject: enabled
        privileged: true
EOF
```

### Deploy Sleep Container

```bash
kubectl label namespace default istio-injection=enabled

kubectl -n default apply -f ${ISTIO_BASE_DIR}/samples/sleep/sleep.yaml

kubectl -n default wait pod -l service.istio.io/canonical-name=sleep --for condition=Ready
```

### Watch Istio Egress Gateway logs

```bash
kubectl logs -f -l istio=egressgateway -c istio-proxy -n istio-system
```

## Files

### **Istio**

- [service-entry.yaml](istio-objects/service-entry.yaml)
- [egress-gateway.yaml](istio-objects/egress-gateway.yaml)
- [virtual-service.yaml](istio-objects/virtual-service.yaml)
- [destination-rule.yaml](istio-objects/destination-rule.yaml)

## Test

```bash
export SOURCE_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})

kubectl exec "$SOURCE_POD" -c sleep -- curl -sL -o /dev/null -D - https://edition.cnn.com/politics
```

### Creating Istio Objects

```bash
kubectl -n default apply -f istio-objects/
```

### Testing

```bash
kubectl exec "$SOURCE_POD" -c sleep -- curl -sL -o /dev/null -D - https://edition.cnn.com/politics
```

## Clean up

```bash
kubectl -n default delete -f istio-objects/
kubectl -n default delete -f ${ISTIO_BASE_DIR}/samples/sleep/sleep.yaml

kubectl -n istio-system apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-operator
  namespace: istio-system
spec:
  profile: default
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: ALLOW_ANY
  components:
    ingressGateways:
    - name: istio-ingressgateway
      namespace: istio-system
      enabled: true
    egressGateways:
    - name: istio-egressgateway
      namespace: istio-system
      enabled: true
  values:
    global:
      proxy:
        autoInject: enabled
        privileged: true
EOF
```

## Examples Index

Click [here](../../README.md) to go back to Examples Index.
