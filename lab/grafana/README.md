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
