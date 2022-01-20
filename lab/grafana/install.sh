#!/bin/bash
kubectl apply -f grafana.yaml

kubectl wait \
  deploy grafana \
  --for=condition=Available \
  --timeout=120s

echo ""
echo "Grafana UI"
echo ""
echo "  http://localhost:3000"
echo ""
echo "    user:     admin"
echo "    password: admin"
echo ""

kubectl port-forward service/grafana 3000:3000
