#!/bin/bash
CLUSTER_NAME="argocd"

kind get clusters \
| grep --quiet "${CLUSTER_NAME?}" || \
kind create cluster \
  --image "kindest/node:v1.24.7" \
  --config "kind-cluster.yaml" \
  --name "${CLUSTER_NAME?}" > /dev/null
