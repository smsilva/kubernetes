#!/bin/bash
kubectl \
  apply \
  -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml

kubectl wait \
  --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

openssl req -x509 \
  -newkey rsa:4096 \
  -nodes \
  -keyout cert.key.pem \
  -out cert.pem \
  -days 365 \
  -subj '/CN=app.example.com'

kubectl create secret tls \
  secret-tls-app.example.com \
  --key cert.key.pem \
  --cert cert.pem

kubectl apply -f ingress.yaml
