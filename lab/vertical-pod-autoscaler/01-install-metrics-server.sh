#!/bin/bash

minikube addons enable metrics-server

# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl \
  --namespace kube-system \
  wait deployment metrics-server \
  --for condition=Available \
  --timeout 3600s
