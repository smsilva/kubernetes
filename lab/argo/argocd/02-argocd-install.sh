#!/bin/bash
set -e

kubectl create namespace argocd

kubectl \
  apply \
  --namespace argocd \
  --filename https://raw.githubusercontent.com/argoproj/argo-cd/v2.0.1/manifests/install.yaml

if ! which argocd &> /dev/null; then
  echo "Need to download and install argocd CLI..."
  sh cli/install.sh
fi

for deploymentName in $(kubectl -n argocd get deploy -o name); do
   echo "Waiting for: ${deploymentName}"

   kubectl \
     --namespace argocd \
     wait \
     --for condition=available \
     --timeout=360s \
     ${deploymentName};
done

# kubectl apply -n argocd -f deploy/kind/argocd-cm.yaml
kubectl \
  --namespace argocd \
  patch service argocd-server \
  --patch '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"nodePort":32443}]}}'

sleep 5
