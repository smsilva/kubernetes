#!/bin/bash
kubectl \
  apply \
  -f https://github.com/datawire/ambassador-operator/releases/download/v1.2.9/ambassador-operator-crds.yaml

kubectl \
  apply \
  -n ambassador \
  -f https://github.com/datawire/ambassador-operator/releases/download/v1.2.9/ambassador-operator-kind.yaml

kubectl \
  -n ambassador \
  wait \
  --timeout=180s \
  --for=condition=deployed ambassadorinstallations/ambassador
