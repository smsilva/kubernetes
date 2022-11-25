# Prometheus

## Create a Kind Cluster

```bash
kind create cluster \
  --image kindest/node:v1.24.0 \
  --config "./kind/cluster.yaml"
```

## New Relic Secret

```bash
# Namespace
kubectl create namespace prometheus

# Secret
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

helm search repo prometheus-community/prometheus

# helm fetch prometheus-community/prometheus --untar

CLUSTER_NAME="kind-93"

helm upgrade \
  --install \
  --namespace prometheus \
  prometheus prometheus/ \
  --set "global.cluster=${CLUSTER_NAME}" \
  --values "prometheus/values-custom.yaml" \
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

## Port Forward

```bash
kubectl \
  --namespace prometheus \
  port-forward service/prometheus-server 9090:80
```
