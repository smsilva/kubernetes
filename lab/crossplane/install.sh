#!/bin/bash

helm repo add crossplane-stable https://charts.crossplane.io/stable

helm repo update

helm install crossplane \
  --create-namespace \
  --namespace crossplane-system \
  --version 1.4.1 \
  crossplane-stable/crossplane

kubectl \
  wait deployment \
  --namespace crossplane-system \
  --selector release=crossplane \
  --for condition=Available \
  --timeout=360s

curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh

kubectl crossplane install configuration registry.upbound.io/xp/getting-started-with-azure:v1.4.1

kubectl get pkg

az ad sp create-for-rbac --sdk-auth --role Owner > "creds.json"

if which jq > /dev/null 2>&1; then
  AZURE_CLIENT_ID=$(jq -r ".clientId" < "./creds.json")
else
  AZURE_CLIENT_ID=$(cat creds.json | grep clientId | cut -c 16-51)
fi

RW_ALL_APPS=1cda74f2-2616-4834-b122-5cb1b07f8a59
RW_DIR_DATA=78c8a3c8-a07e-4b9e-af1b-b5ccab50a175
AAD_GRAPH_API=00000002-0000-0000-c000-000000000000

az ad app permission add \
  --id "${AZURE_CLIENT_ID?}" \
  --api ${AAD_GRAPH_API?} \
  --api-permissions ${RW_ALL_APPS?}=Role ${RW_DIR_DATA?}=Role

az ad app permission grant \
  --id "${AZURE_CLIENT_ID?}" \
  --api ${AAD_GRAPH_API?} \
  --expires never > /dev/null

az ad app permission admin-consent \
  --id "${AZURE_CLIENT_ID?}"

kubectl create secret generic azure-creds \
  --namespace crossplane-system \
  --from-file=creds=./creds.json

cat <<EOF | kubectl apply -f -
apiVersion: azure.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-creds
      key: creds
EOF

cat <<EOF | kubectl apply -f -
apiVersion: database.example.org/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: my-db
  namespace: default
spec:
  parameters:
    storageGB: 20
  compositionSelector:
    matchLabels:
      provider: azure
  writeConnectionSecretToRef:
    name: db-conn
EOF

kubectl get postgresqlinstance my-db

kubectl get crossplane -l crossplane.io/claim-name=my-db

kubectl describe secrets db-conn

cat <<EOF | kubectl apply -f - 
apiVersion: v1
kind: Pod
metadata:
  name: see-db
  namespace: default
spec:
  containers:
  - name: see-db
    image: postgres:12
    command: ['psql']
    args: ['-c', 'SELECT current_database();']
    env:
    - name: PGDATABASE
      value: postgres
    - name: PGHOST
      valueFrom:
        secretKeyRef:
          name: db-conn
          key: endpoint
    - name: PGUSER
      valueFrom:
        secretKeyRef:
          name: db-conn
          key: username
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: db-conn
          key: password
    - name: PGPORT
      valueFrom:
        secretKeyRef:
          name: db-conn
          key: port
EOF

kubectl delete pod see-db

kubectl delete postgresqlinstance my-db

kind delete cluster --name demo

QUERY_EXPRESSION=$(printf "[?appId=='%s']" ${AZURE_CLIENT_ID?})

az ad sp list \
  --all \
  --query "${QUERY_EXPRESSION?}"

az ad sp delete \
  --id ${AZURE_CLIENT_ID?}
