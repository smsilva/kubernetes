#!/bin/bash
git clone https://github.com/zalando/postgres-operator.git

cd postgres-operator

# Apply the manifests in the following order
kubectl create -f manifests/configmap.yaml  # configuration
kubectl create -f manifests/operator-service-account-rbac.yaml  # identity and permissions
kubectl create -f manifests/postgres-operator.yaml  # deployment
kubectl create -f manifests/api-service.yaml  # operator API to be used by UI

sleep 5

# Create a Postgres cluster
kubectl create -f manifests/minimal-postgres-manifest.yaml

kubectl wait \
  --for=jsonpath='{.status.PostgresClusterStatus}'=Running \
  postgresql acid-minimal-cluster \
  --timeout=360s
