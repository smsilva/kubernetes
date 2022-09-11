#!/bin/bash

kind create cluster \
  --image kindest/node:v1.24.0 \
  --config kind-cluster.yaml \
  --name istio
