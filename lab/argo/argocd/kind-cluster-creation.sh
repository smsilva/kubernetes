#!/bin/bash

echo "Kind Cluster Creation"

kind create cluster \
  --config kind-cluster.yaml \
  --name argocd
