# Ingress

## Create a Kind Cluster

```bash
kind/creation
```

## New Relic Secret

```bash
kubectl create namespace prometheus

kubectl -n prometheus apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: newrelic-license
type: Opaque
stringData:
  license: "${NEW_RELIC_LICENSE_KEY}"
EOF
```

## Prometheus Helm Install

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm search repo prometheus-community

helm fetch prometheus-community/prometheus --untar

helm upgrade \
  --install \
  --namespace prometheus \
  prometheus prometheus/ \
  --wait && \
kubectl wait pod \
  --namespace prometheus \
  --selector component=server \
  --for=condition=Ready \
  --timeout=360s && \
kubectl logs \
  --namespace prometheus \
  --selector component=server \
  --container prometheus-server \
  --follow
```

## Deploy httpbin

```bash
kubectl create namespace example

kubectl -n example apply -f httpbin/deployment.yaml
kubectl -n example apply -f httpbin/service.yaml
```
