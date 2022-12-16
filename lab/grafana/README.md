# Grafana

## Secret

```bash
kubectl create namespace grafana

kubectl apply \
  --namespace grafana \
  --filename - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: grafana
type: Opaque
stringData:
  admin-user: "admin"
  admin-password: "${GRAFANA_ADMIN_PASSWORD}"
EOF
```

## Install

```bash
helm repo add grafana https://grafana.github.io/helm-charts

helm search repo grafana/grafana

helm install \
  --namespace grafana \
  --create-namespace \
  grafana grafana/grafana \
  --set "admin.existingSecret=grafana" \
  --wait
```

## Port Forward

```bash
kubectl \
  --namespace grafana \
  port-forward service/grafana 3000:80
```

## Prometheus Data Source

```bash
http://prometheus-server.prometheus.svc
```

## Dashboards

| Description                                    | URL                                                                                      | ID      |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------- | ------- |
| ArgoCD                                         | https://grafana.com/grafana/dashboards/14584-argocd                                      | `14584` |
| CoreDNS                                        | https://grafana.com/grafana/dashboards/12382-k8s-coredns                                 | `12382` |
| Istio Control Plane Dashboard                  | https://grafana.com/grafana/dashboards/7645-istio-control-plane-dashboard                | `7645`  |
| Istio Mesh Dashboard                           | https://grafana.com/grafana/dashboards/7639-istio-mesh-dashboard                         | `7639`  |
| Istio Service Dashboard                        | https://grafana.com/grafana/dashboards/7636-istio-service-dashboard                      | `7636`  |
| Istio Workload Dashboard                       | https://grafana.com/grafana/dashboards/7630-istio-workload-dashboard                     | `7630`  |
| Kubernetes cluster monitoring (via Prometheus) | https://grafana.com/grafana/dashboards/3119-kubernetes-cluster-monitoring-via-prometheus | `3119`  |
| Prometheus 2.0 Overview                        | https://grafana.com/grafana/dashboards/3662-prometheus-2-0-overview                      | `3662`  |
