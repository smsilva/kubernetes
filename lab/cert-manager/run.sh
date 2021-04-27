#!/bin/bash
kubectl apply \
  --validate=false \
  --filename install/cert-manager-v0.15.1.yaml

for DEPLOYMENT_NAME in $(kubectl --namespace cert-manager get deploy -o jsonpath='{.items[*].metadata.name}'); do
  kubectl --namespace cert-manager \
    wait \
      --timeout=3600s \
      --for condition=Available \
      deployment ${DEPLOYMENT_NAME}
done

kubectl --namespace cert-manager \
  get pods,services
