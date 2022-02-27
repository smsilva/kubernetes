#!/bin/bash

export CLUSTER_NAME="wasp-na-sbx-a"

aks-cluster/create.sh ${CLUSTER_NAME}

kind/create-cluster.sh

external-secrets/install.sh

argocd/install.sh

helm install \
  --wait \
  --set "cluster.name=${CLUSTER_NAME}" \
  argocd-secrets \
  ./argocd-secrets

helm install \
  --wait \
  --set "cluster.name=${CLUSTER_NAME}" \
  argocd-applications \
  ./argocd-applications
