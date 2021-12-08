#!/bin/bash

VERSION="1.6.1"

kubectl apply \
  --filename "https://github.com/jetstack/cert-manager/releases/download/v${VERSION?}/cert-manager.yaml"

for DEPLOYMENT_NAME in $(kubectl --namespace cert-manager get deploy -o jsonpath='{.items[*].metadata.name}'); do
  kubectl --namespace cert-manager \
    wait \
      --timeout=3600s \
      --for condition=Available \
      deployment ${DEPLOYMENT_NAME}
done

kubectl --namespace cert-manager \
  get pods,services
