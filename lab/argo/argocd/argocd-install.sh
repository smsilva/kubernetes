#!/bin/bash
set -e

helm repo \
  add argo https://argoproj.github.io/argo-helm &> /dev/null

helm repo \
  update argo &> /dev/null

helm search repo argo/argo-cd

echo ""
echo "Helm install/upgrade..."
echo ""

helm upgrade \
  --install \
  --namespace argocd \
  --create-namespace \
  argocd argo/argo-cd \
  --values values/additional-projects.yaml \
  --values values/configs-known-hosts.yaml \
  --values values/extra-objects.yaml \
  --values values/extra-volumes.yaml \
  --values values/metrics.yaml \
  --values values/resource-customizations.yaml \
  --values values/service.yaml \
  --wait

echo ""

for DEPLOYMENT in $(kubectl \
  --namespace argocd \
  get deploy \
  --output name); do
  echo "Waiting for: ${DEPLOYMENT}"

  kubectl \
    --namespace argocd \
    wait \
    --for condition=Available \
    --timeout=360s \
    "${DEPLOYMENT}";

  echo ""
done

if ! which argocd &> /dev/null; then
  echo "Need to download and install argocd CLI..."
  
  sh cli/install.sh
  
  echo ""
fi
