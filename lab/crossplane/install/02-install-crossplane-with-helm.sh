#!/bin/bash

CROSSPLANE_VERSION="1.4.1"

if ! grep --quiet crossplane-stable <<< "$(helm repo list)"; then
  echo "Adding Crosplane Stable Helm Chart"
  helm repo add crossplane-stable https://charts.crossplane.io/stable
  helm repo update
else
  helm repo list | grep -E "NAME|crossplane-stable"
fi

helm install crossplane \
  --create-namespace \
  --namespace crossplane-system \
  --version "${CROSSPLANE_VERSION?}" \
  crossplane-stable/crossplane && \
kubectl \
  wait deployment \
  --namespace crossplane-system \
  --selector release=crossplane \
  --for condition=Available \
  --timeout=360s

if ! which kubectl-crossplane &> /dev/null; then
  curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh
fi

kubectl crossplane --version                   && echo ""
kubectl get namespaces                         && echo ""
kubectl get pods --namespace crossplane-system && echo ""
kubectl api-resources | grep crossplane
