#!/bin/bash
cluster_name="argocd"

kind get clusters \
| grep --quiet "${cluster_name?}" || \
kind create cluster \
  --image "kindest/node:v1.24.7" \
  --config "kind-cluster.yaml" \
  --name "${cluster_name?}" > /dev/null
