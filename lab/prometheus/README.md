# Prometheus

## Create a Kind Cluster

```bash
kind create cluster \
  --image "kindest/node:v1.24.7" \
  --config "./kind/cluster.yaml"
```

or

```bash
k3d cluster create \
  --api-port 6550 \
  --port "8888:80@loadbalancer" \
  --agents 2
```

## New Relic Secret

```bash
# Namespace
kubectl create namespace prometheus

# Secret
kubectl apply \
  --namespace prometheus \
  --filename - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: newrelic-license
type: Opaque
stringData:
  license: "${NEW_RELIC_LICENSE_KEY?}"
EOF
```

## Prometheus Helm Chart Fetch

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update prometheus-community

helm search repo prometheus-community/prometheus

# helm fetch prometheus-community/prometheus --untar
```

## Prometheus Helm Install

```bash
export CLUSTER_NAME="k3d-156"

helm upgrade \
  --install \
  --create-namespace \
  --namespace prometheus \
  prometheus prometheus/ \
  --set "global.cluster=${CLUSTER_NAME-undefined}" \
  --values "prometheus/values-custom.yaml" \
  --wait && \
kubectl wait pod \
  --namespace prometheus \
  --selector app.kubernetes.io/component=server \
  --for=condition=Ready \
  --timeout=360s && \
kubectl logs \
  --namespace prometheus \
  --selector app.kubernetes.io/component=server \
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
# CoreDNS Patch
PATCH_FILE=$(mktemp)

cat <<EOF > ${PATCH_FILE?}
metadata:
  labels:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9153"
EOF

kubectl patch service kube-dns \
  --patch-file=${PATCH_FILE?} \
  --namespace "kube-system"

kubectl get service kube-dns --output yaml
```

### NRQL

```sql
SELECT histogrampercentile(coredns_dns_request_duration_seconds_bucket, (100 * 0.99), (100 * 0.5)) FROM Metric SINCE 60 MINUTES AGO UNTIL NOW FACET tuple(server, zone) LIMIT 100 TIMESERIES 300000 SLIDE BY 10000
```

## PromQL

### Gauge

```bash
# Running Pods
kubectl get pods -o wide -A | sed 1d | wc -l

# Running Pods per Node by Instance
sum by (instance) (kubelet_running_pods)

# Running Pods per Node
sum(kubelet_running_pods)

# Memory Bytes by Nodes
sum by (instance) (process_resident_memory_bytes{job="kubernetes-nodes"})

  # Result:
  {instance="kind-control-plane"} 82018304
  {instance="kind-worker"} 94068736
  {instance="kind-worker2"} 97607680
  {instance="kind-worker3"} 95772672

# without
sum without(job) (process_resident_memory_bytes{job="kubernetes-nodes"})

  # Result:
  {beta_kubernetes_io_arch="amd64", beta_kubernetes_io_os="linux", instance="kind-control-plane", kubernetes_io_arch="amd64", kubernetes_io_hostname="kind-control-plane", kubernetes_io_os="linux"} 84721664
  {beta_kubernetes_io_arch="amd64", beta_kubernetes_io_os="linux", instance="kind-worker", kubernetes_io_arch="amd64", kubernetes_io_hostname="kind-worker", kubernetes_io_os="linux"} 95027200
  {beta_kubernetes_io_arch="amd64", beta_kubernetes_io_os="linux", instance="kind-worker2", kubernetes_io_arch="amd64", kubernetes_io_hostname="kind-worker2", kubernetes_io_os="linux"} 98439168
  {beta_kubernetes_io_arch="amd64", beta_kubernetes_io_os="linux", instance="kind-worker3", kubernetes_io_arch="amd64", kubernetes_io_hostname="kind-worker3", kubernetes_io_os="linux"} 94777344
```

### Counter

```bash
# CoreDNS Requests
sum by(proto,server,type,zone) (rate(coredns_dns_requests_total[10m]))
```

### Summary

Calculating Average Size of an Event.

```bash
  sum without (instance) (rate(coredns_dns_request_duration_seconds_sum[5m]))
/
  sum without (instance) (rate(coredns_dns_request_duration_seconds_count[5m]))
```

```bash
  sum without (instance) (rate(coredns_dns_request_size_bytes_sum[5m]))
/
  sum without (instance) (rate(coredns_dns_request_size_bytes_count[5m]))
```

### Histogram

```bash
# CoreDNS
# https://sysdig.com/blog/how-to-monitor-coredns
histogram_quantile(0.99, sum(rate(coredns_dns_request_duration_seconds_bucket{job="kubernetes-coredns"}[1h])) by(server, zone, le))
```

## Metrics

### curl pod

```bash
# curl pod on default namespace
kubectl run curl \
  --namespace default \
  --image=silviosilva/utils \
  --command -- sleep infinity && \
kubectl wait pod curl \
  --namespace default \
  --for condition=Ready \
  --timeout 360s
```

### argocd server

```bash

kubectl \
  --namespace default \
  exec curl -- curl \
    --include \
    --silent \
    --request GET http://argocd-server-metrics.argocd:8083/metrics \
| grep "^argocd"
```

### spring-actuator-demo

```bash
kubectl create namespace demo

kubectl config set-context \
  --current \
  --namespace demo

watch -n 3 'kubectl get deploy,pods,svc,ing -o wide'

kubectl apply -f deploy/
```
