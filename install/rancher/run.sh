#!/bin/bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable

helm install rancher rancher-stable/rancher \
  --create-namespace \
  --namespace cattle-system \
  --set hostname=rancher.silvios.me \
  --set ingress.tls.source=secret

kubectl -n cattle-system rollout status deploy/rancher

kubectl -n cattle-system get deploy rancher
