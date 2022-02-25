#!/bin/bash

kubectl apply --kustomize base

for DEPLOYMENT_NAME in $(kubectl -n argocd get deploy -o name); do
  kubectl \
    --namespace argocd \
    wait \
    --for condition=Available \
    --timeout=360s \
    "${DEPLOYMENT_NAME}";
done
