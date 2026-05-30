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
  --values "values/resource-customizations.yaml" \
  --values "values/service.yaml" \
  --wait &> /dev/null

echo ""

for deployment in $(
  kubectl \
    --namespace argocd \
    get deploy \
    --output name
); do
  kubectl \
    --namespace argocd \
    wait \
    --for condition=Available \
    --timeout=360s \
    "${deployment}" &> /dev/null
done

echo ""

if ! which argocd &> /dev/null; then
  echo "ArgoCD CLI Install..."

  sh cli/install.sh
fi

argocd_password=$(
  kubectl \
    --namespace argocd \
    get secret argocd-initial-admin-secret \
    --output jsonpath="{.data.password}" \
  | base64 --decode
)

echo ""

echo "ArgoCD CLI login"

argocd login localhost:32080 \
  --username admin \
  --password "${argocd_password}" \
  --insecure

echo ""

argocd app list
