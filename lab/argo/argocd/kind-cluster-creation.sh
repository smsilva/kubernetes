#!/bin/bash
kind get clusters | grep --quiet argocd || \
kind create cluster \
  --image kindest/node:v1.24.0 \
  --config kind-cluster.yaml \
  --name argocd > /dev/null
