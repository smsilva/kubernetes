# Observability

## Collecting Metrics for TCP Services

### Setup

Run the [setup](../../../setup-istio-with-kind-and-helm) script:

```bash
../../../setup-istio-with-kind-and-helm
```

### Deploy **Bookinfo Application**

https://istio.io/latest/docs/examples/bookinfo

```bash
kubectl label namespace default istio-injection=enabled

kubectl apply -f "${ISTIO_BASE_DIR?}/samples/bookinfo/platform/kube/bookinfo.yaml"

kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"

kubectl apply -f "${ISTIO_BASE_DIR?}/samples/bookinfo/networking/bookinfo-gateway.yaml"

export GATEWAY_URL="127.0.0.1:32080"

curl -s "http://${GATEWAY_URL}/productpage" | grep -o "<title>.*</title>"

${ISTIO_BASE_DIR?}/samples/bookinfo/platform/kube/cleanup.sh

```

### Deploy **Prometheus**

https://istio.io/latest/docs/ops/integrations/prometheus/

```bash
kubectl apply -f "${ISTIO_BASE_DIR?}/samples/addons/prometheus.yaml"
```

### 1. Setup Bookinfo to use MongoDB.

```bash
kubectl apply -f "${ISTIO_BASE_DIR?}/samples/bookinfo/platform/kube/bookinfo-ratings-v2.yaml"

kubectl apply -f "${ISTIO_BASE_DIR?}/samples/bookinfo/platform/kube/bookinfo-db.yaml"

kubectl apply -f "${ISTIO_BASE_DIR?}/samples/bookinfo/networking/destination-rule-all.yaml"

kubectl get destinationrules -o yaml

kubectl apply -f "${ISTIO_BASE_DIR?}/samples/bookinfo/networking/virtual-service-ratings-db.yaml"

watch -n 5 'curl -s "http://${GATEWAY_URL}/productpage"'

istioctl dashboard prometheus
```
