#!/bin/bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.1/deploy/gatekeeper.yaml

for DEPLOYMENT_NAME in $(kubectl -n gatekeeper-system get deploy -o jsonpath='{range .items[*].metadata}{.name}{"\n"}{end}'); do
  kubectl -n gatekeeper-system \
    wait \
      --timeout=3600s \
      --for condition=Available \
      deployment ${DEPLOYMENT_NAME}
done

kubectl apply -f k8srequiredlabels.yaml
