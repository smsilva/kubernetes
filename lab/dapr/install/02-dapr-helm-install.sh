#!/bin/bash

# Install with Helm (advanced)
# https://docs.dapr.io/operations/hosting/kubernetes/kubernetes-deploy/#install-with-helm-advanced

helm repo add dapr https://dapr.github.io/helm-charts/

helm repo update

helm search repo dapr --devel --versions

helm upgrade \
  --install dapr dapr/dapr \
  --version=1.2 \
  --namespace dapr-system \
  --create-namespace \
  --wait
