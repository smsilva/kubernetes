#!/bin/bash
set -e

helm repo add argo https://argoproj.github.io/argo-helm

helm repo update argo

helm search repo argo/argo-cd

helm install \
  --namespace argocd \
  --create-namespace \
  argocd argo/argo-cd \
  --values values/additional-projects.yaml \
  --values values/configs-known-hosts.yaml \
  --values values/extra-objects.yaml \
  --values values/extra-volumes.yaml \
  --values values/resource-customizations.yaml \
  --values values/service.yaml \
  --wait

if ! which argocd &> /dev/null; then
  echo "Need to download and install argocd CLI..."
  sh cli/install.sh
fi

for DEPLOYMENT in $(kubectl -n argocd get deploy -o name); do
   echo "Waiting for: ${DEPLOYMENT}"

   kubectl \
     --namespace argocd \
     wait \
     --for condition=Available \
     --timeout=360s \
     "${DEPLOYMENT}";
done
