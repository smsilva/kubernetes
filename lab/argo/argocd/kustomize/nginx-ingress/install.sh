#!/bin/bash

helm upgrade \
  --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --version 4.0.17 \
  --namespace argocd \
  --values nginx-ingress-values.yaml \
  --wait
