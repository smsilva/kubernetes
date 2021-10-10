#!/bin/bash
KIND_CLUSTER_NAME="crossplane"
KIND_CLUSTER_CONFIG_FILE="kind/kind-cluster.yaml"

kind create cluster \
  --config ${KIND_CLUSTER_CONFIG_FILE?} \
  --name ${KIND_CLUSTER_NAME?}

for NODE in $(kubectl get nodes --output name); do
  kubectl wait ${NODE} \
    --for condition=Ready \
    --timeout=360s
done

if ! grep --quiet crossplane-stable <<< "$(helm repo list)"; then
  echo "Adding Crosplane Stable Helm Chart"
  helm repo add crossplane-stable https://charts.crossplane.io/stable
  helm repo update
else
  helm repo list | grep -E "NAME|crossplane-stable"
fi

helm install crossplane \
  --create-namespace \
  --namespace crossplane-system \
  --version 1.4.1 \
  crossplane-stable/crossplane && \
kubectl \
  wait deployment \
  --namespace crossplane-system \
  --selector release=crossplane \
  --for condition=Available \
  --timeout=360s

if ! which kubectl-crossplane &> /dev/null; then
  curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh
fi

kubectl crossplane --version

echo ""

kubectl get namespaces

echo ""

kubectl get pods --namespace crossplane-system

echo ""

kubectl api-resources | grep crossplane
