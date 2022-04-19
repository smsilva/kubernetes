#!/bin/bash

# https://kind.sigs.k8s.io/docs/user/using-wsl2/#setting-up-docker-in-wsl2

kind create cluster \
  --config=cluster-config.yml

for NODE in $(kubectl get nodes --output name); do
  kubectl wait ${NODE} \
    --for condition=Ready \
    --timeout=360s
done

kubectl create deployment nginx \
  --image=nginx \
  --port=80

kubectl wait deployment nginx \
  --for=condition=Available \
  --timeout=360s

kubectl create service nodeport nginx \
  --tcp=80:80 \
  --node-port=30000

watch -n 3 'curl -si localhost:30000'

