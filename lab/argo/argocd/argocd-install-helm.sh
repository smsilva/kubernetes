#!/bin/bash
helm repo add \
  --force-update argoproj https://argoproj.github.io/argo-helm

helm repo update

helm search repo argoproj

helm upgrade argocd argoproj/argo-cd \
  --create-namespace \
  --namespace argocd \
  --set "server.config.url=https://argocd.wasp.sandbox.silvios.me" \
  --set "configs.repositories.github-smsilva-argocd.url=git@github.com:smsilva/argocd.git" \
  --set "configs.repositories.github-smsilva-argocd.name=github-smsilva-argocd" \
  --set "configs.repositories.github-smsilva-argocd.type=git" \
  --wait
