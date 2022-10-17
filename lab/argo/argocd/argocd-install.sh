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
  --values values/configs-known-hosts.yaml \
  --values values/extra-objects.yaml \
  --values values/extra-volumes.yaml \
  --values values/metrics.yaml \
  --values values/notifications.yaml \
  --values values/resource-customizations.yaml \
  --values values/service.yaml \
  --wait &> /dev/null

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

if ! which argocd &> /dev/null; then
  echo "Need to download and install argocd CLI..."

  sh cli/install.sh
fi
