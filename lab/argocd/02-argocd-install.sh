#!/bin/bash
set -e

SECONDS=0

kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

if ! which argocd &> /dev/null; then
  echo "Need to download and install argocd CLI..."

  VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

  echo "Downloading version: ${VERSION}"

  sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64

  sudo chmod +x /usr/local/bin/argocd
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
