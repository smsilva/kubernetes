#!/bin/bash
helm repo \
  add argo https://argoproj.github.io/argo-helm &> /dev/null

helm repo \
  update argo &> /dev/null

echo ""
echo "Installing argo-cd..."

helm upgrade \
  --install \
  --namespace argocd \
  --create-namespace \
  argocd argo/argo-cd \
  --values "values/notifications-base.yaml" \
  --values "values/resource-customizations.yaml" \
  --values "values/service.yaml" \
  --wait &> /dev/null

echo ""

for DEPLOYMENT in $(kubectl \
  --namespace argocd \
  get deploy \
  --output name); do
  kubectl \
    --namespace argocd \
    wait \
    --for condition=Available \
    --timeout=360s \
    "${DEPLOYMENT}" &> /dev/null
done

echo ""

if ! which argocd &> /dev/null; then
  echo "ArgoCD CLI Install..."

  sh cli/install.sh
fi
