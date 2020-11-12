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
  -n ambassador \
  wait \
  --timeout=180s \
  --for=condition=deployed ambassadorinstallations/ambassador
