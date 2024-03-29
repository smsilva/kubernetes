#!/bin/bash
kubectl create namespace grafana

kubectl -n grafana apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: grafana
type: Opaque
stringData:
  admin-user: "admin"
  admin-password: "strongpassword"
EOF

kubectl wait deploy grafana \
  --namespace grafana \
  --for=condition=Available \
  --timeout=120s

echo ""
echo "Grafana UI"
echo ""
echo "  http://localhost:3000"
echo ""
echo "    user:     admin"
echo "    password: strongpassword"
echo ""

helm repo add grafana https://grafana.github.io/helm-charts

helm repo update

helm install \
  --namespace grafana \
  --create-namespace \
  grafana grafana/grafana \
  --set "admin.existingSecret=grafana" \
  --wait

kubectl \
  --namespace grafana \
  port-forward service/grafana 3000:80
