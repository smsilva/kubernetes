#!/bin/bash
set -e

LATEST_GITHUB_RELEASE_VERSION=$(curl -sL https://github.com/argoproj/argo-cd/releases | grep -oP 'releases/tag/\K[^\"]+' | sort --version-sort | tail -1)

echo "ARGOCD_VERSION.: ${LATEST_GITHUB_RELEASE_VERSION?}"
echo "CLUSTER_TYPE...: ${CLUSTER_TYPE?}"

kubectl create namespace argocd

kubectl \
  apply \
  --namespace argocd \
  --filename https://raw.githubusercontent.com/argoproj/argo-cd/${LATEST_GITHUB_RELEASE_VERSION?}/manifests/install.yaml

if ! which argocd &> /dev/null; then
  echo "Need to download and install argocd CLI..."
  sh cli/install.sh
fi

for deploymentName in $(kubectl -n argocd get deploy -o name); do
   echo "Waiting for: ${deploymentName}"

   kubectl \
     --namespace argocd \
     wait \
     --for condition=Available \
     --timeout=360s \
     "${deploymentName}";
done

kubectl apply \
  --namespace argocd \
  --filename "deploy/${CLUSTER_TYPE?}/"

echo ""
