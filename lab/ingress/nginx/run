#!/bin/bash
kubectl \
  apply \
  --filename https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml

kubectl wait \
  --namespace ingress-nginx \
  --for condition=Ready pod \
  --selector app.kubernetes.io/component=controller \
  --timeout=360s
