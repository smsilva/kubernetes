# Prometheus

## Create a Kind Cluster

```bash
kind create cluster \
  --image kindest/node:v1.24.7 \
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

helm repo update prometheus-community

helm search repo prometheus-community/prometheus

# helm fetch prometheus-community/prometheus --untar

CLUSTER_NAME="kind-126"

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

## Local Acess

```bash
http://localhost:32081
```

## Port Forward

```bash
kubectl \
  --namespace prometheus \
  port-forward service/prometheus-server 9090:80
```

## New Relic

### Patch

```bash
PATCH_FILE=$(mktemp)

cat <<EOF > ${PATCH_FILE?}
metadata:
  annotations: {}
  labels:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
EOF

kubectl patch service kube-dns \
  --patch-file=${PATCH_FILE?} \
  --namespace kube-system

kubectl get svc kube-dns --output yaml
```

### NRQL

```sql
SELECT histogrampercentile(coredns_dns_request_duration_seconds_bucket, (100 * 0.99), (100 * 0.5)) FROM Metric SINCE 60 MINUTES AGO UNTIL NOW FACET tuple(server, zone) LIMIT 100 TIMESERIES 300000 SLIDE BY 10000
```
