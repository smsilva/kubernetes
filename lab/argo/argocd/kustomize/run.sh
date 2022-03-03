#!/bin/bash

export ENVIRONMENT_NAME="wasp-sbx-na"
export STACK_INSTANCE_NAME=${ENVIRONMENT_NAME}
export CLUSTER_NAME="${ENVIRONMENT_NAME}-eus2-aks-a"
export KEYVAULT_NAME="${ENVIRONMENT_NAME}-eus2"

stackrun silviosilva/azure-wasp-foundation:0.1.0 apply -auto-approve -var="name=${ENVIRONMENT_NAME}"

aks-cluster/create.sh "${CLUSTER_NAME}"

kind/create-cluster.sh

external-secrets/install.sh "${KEYVAULT_NAME}"

argocd/install.sh

helm install \
  --wait \
  --set "cluster.name=eus2-aks-a" \
  argocd-secrets \
  ./argocd-secrets

helm install \
  --wait \
  --set "cluster.name=eus2-aks-a" \
  argocd-applications \
  ./argocd-applications
