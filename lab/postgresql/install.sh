#!/bin/bash
git clone https://github.com/zalando/postgres-operator.git

cd postgres-operator

git checkout bump-v1.7.1

helm install \
  postgres-operator ./charts/postgres-operator \
  --wait

# create a Postgres cluster
kubectl create -f manifests/minimal-postgres-manifest.yaml

kubectl wait \
  --for=jsonpath='{.status.PostgresClusterStatus}'=Creating \
  postgresql acid-minimal-cluster \
  --timeout=360s

POSTGRESQL_USER_NAME=$(kubectl get secret postgres.acid-minimal-cluster.credentials.postgresql.acid.zalan.do -o jsonpath='{.data.username}' | base64 -d)
POSTGRESQL_USER_PASSWORD=$(kubectl get secret postgres.acid-minimal-cluster.credentials.postgresql.acid.zalan.do -o jsonpath='{.data.password}' | base64 -d)

echo "POSTGRESQL_USER_NAME.....: ${POSTGRESQL_USER_NAME}" && \
echo "POSTGRESQL_USER_PASSWORD.: ${POSTGRESQL_USER_PASSWORD}"
