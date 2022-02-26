#!/bin/bash
SCRIPT_PATH="$(dirname $0)"

KIND_CLUSTER_NAME="argocd"
KIND_CLUSTER_CONFIG_FILE="${SCRIPT_PATH}/kind-example-config.yaml"

kind create cluster \
  --config ${KIND_CLUSTER_CONFIG_FILE} \
  --name ${KIND_CLUSTER_NAME}

for NODE in $(kubectl get nodes --output name); do
  kubectl wait ${NODE} \
    --for condition=Ready \
    --timeout=360s
done
