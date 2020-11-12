#!/bin/bash
kubectl \
  apply \
  -f https://github.com/datawire/ambassador-operator/releases/latest/download/ambassador-operator-crds.yaml

kubectl \
  apply \
  -n ambassador \
  -f https://github.com/datawire/ambassador-operator/releases/latest/download/ambassador-operator-kind.yaml

kubectl config set-context --current --namespace ambassador

kubectl \
  wait \
  --timeout=180s \
  -n ambassador \
  --for=condition=deployed ambassadorinstallations/ambassador

kubectl create namespace dev

kubectl config set-context --current --namespace dev

kubectl -n dev apply -f httpbin/

kubectl \
  -n dev \
  wait \
  deploy httpbin \
  --for condition=Available \
  --timeout=180s

kubectl \
  -n dev \
  apply \
  -f ingress.yaml

sleep 3

curl localhost/get
