#!/bin/bash
kubectl label namespace default istio-injection=enabled

kubectl -n default apply -f ${ISTIO_BASE_DIR}/samples/bookinfo/platform/kube/bookinfo.yaml

kubectl -n default apply -f ${ISTIO_BASE_DIR}/samples/bookinfo/networking/bookinfo-gateway.yaml

kubectl -n default apply -f ${ISTIO_BASE_DIR}/samples/bookinfo/networking/destination-rule-all.yaml

echo "Waiting for all Deployments become Available (this could take several minutes due to the time to download container images)"

for DEPLOYMENT_NAME in $(kubectl -n default get deploy -o jsonpath='{.items[*].metadata.name}'); do
  kubectl -n default \
    wait \
      --timeout=3600s \
      --for condition=Available \
      deployment ${DEPLOYMENT_NAME}
done
