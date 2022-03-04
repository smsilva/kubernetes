#!/bin/bash

environment/create.sh "wasp-sbx-na"
aks-cluster/create.sh "wasp-sbx-na-eus2-aks-a"
aks-cluster/create.sh "wasp-sbx-na-ceus-aks-a"

# ArgoCD Cluster
kind/create-cluster.sh

# External Secrets Install
#
#   - secret: azurerm-service-principal
#
#   - ClusterSecretStores: [
#       "wasp-sbx-na-eus2",
#       "wasp-sbx-na-ceus"
#     ] 
#
external-secrets/install.sh

# ArgoCD Install using Kustomize
argocd/install.sh

# ArgoCD Cluster Credentials
helm upgrade \
  --install \
  --wait \
  argocd-secrets \
  ./argocd-secrets

# ArgoCD Applications
kubectl apply -f argocd-applications/ --context kind-argocd

# Cleanup
aks-cluster/destroy.sh "wasp-sbx-na-eus2-aks-a"
aks-cluster/destroy.sh "wasp-sbx-na-ceus-aks-a"
environment/destroy.sh "wasp-sbx-na"
kind delete cluster --name argocd
