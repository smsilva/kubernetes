#!/bin/bash
kubectl create namespace dev

kubectl config \
  set-context --current --namespace dev

kubectl -n dev apply -f httpbin/

kubectl \
  -n dev \
  wait \
  deploy httpbin \
  --for condition=Available \
  --timeout=180s
