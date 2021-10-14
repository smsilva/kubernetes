#!/bin/bash
KIND_CLUSTER_NAME="crossplane"
KIND_CLUSTER_CONFIG_FILE="${1}"

kind create cluster \
  --config ${KIND_CLUSTER_CONFIG_FILE?} \
  --name ${KIND_CLUSTER_NAME?}

for NODE in $(kubectl get nodes --output name); do
  kubectl wait "${NODE}" \
    --for condition=Ready \
    --timeout=360s
done
