#!/bin/bash
kind create cluster \
  --image kindest/node:v1.24.0 \
  --config kind-cluster-config.yaml

watch -n 3 ./follow.sh
