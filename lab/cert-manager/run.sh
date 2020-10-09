#!/bin/bash
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.2/cert-manager.yaml

for DEPLOYMENT_NAME in $(kubectl --namespace cert-manager get deploy -o jsonpath='{.items[*].metadata.name}'); do
  kubectl --namespace cert-manager \
    wait \
      --timeout=3600s \
      --for condition=Available \
      deployment ${DEPLOYMENT_NAME}
done

kubectl --namespace cert-manager \
  get pods,service
