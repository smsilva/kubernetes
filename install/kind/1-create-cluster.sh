#!/bin/bash
KIND_CLUSTER_NAME="${USER}"
KIND_CLUSTER_CONFIG_FILE="kind-example-config.yaml"

kind create cluster \
  --config ${KIND_CLUSTER_CONFIG_FILE} \
  --name ${KIND_CLUSTER_NAME}

for NODE in $(kubectl get nodes --output name); do
  kubectl wait ${NODE} \
    --for condition=Ready \
    --timeout=360s
done
