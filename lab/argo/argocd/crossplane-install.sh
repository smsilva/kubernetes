#!/bin/bash
helm repo \
  add crossplane-stable https://charts.crossplane.io/stable &> /dev/null

helm repo \
  update crossplane-stable &> /dev/null

echo ""
echo "Installing crossplane..."

helm install crossplane \
  --create-namespace \
  --namespace crossplane-system \
  crossplane-stable/crossplane \
  --version 2.2.1 \
  --wait &> /dev/null

echo ""

kubectl \
  wait deployment \
    --namespace crossplane-system \
    --selector release=crossplane \
    --for condition=Available \
    --timeout=360s &> /dev/null

echo ""

kubectl get pods --namespace crossplane-system
