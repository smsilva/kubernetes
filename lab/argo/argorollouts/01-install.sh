#!/bin/bash

# https://argoproj.github.io/argo-rollouts/installation/#controller-installation

kubectl create namespace argo-rollouts

kubectl apply \
  --namespace argo-rollouts \
  --filename https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/install.yaml

kubectl wait \
  --namespace argo-rollouts \
  --for condition=Available \
  --timeout 360s \
  deployment argo-rollouts

kubectl argo rollouts version
