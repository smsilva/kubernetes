#!/bin/bash
set -e

kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

if ! which argocd &> /dev/null; then
  echo "Need to download and install argocd CLI..."
  sh cli/install.sh
fi

for deploymentName in $(kubectl -n argocd get deploy -o name); do
   echo "Waiting for: ${deploymentName}"

   kubectl \
     -n argocd \
     wait \
     --for condition=available \
     --timeout=240s \
     ${deploymentName};
done

kubectl apply -n argocd -f argocd-server-service.yaml

sleep 5
