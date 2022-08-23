#!/bin/bash

set -e

CLUSTER_TYPE=${1-kind}

if [[ -z "${CLUSTER_TYPE}" ]]; then
  echo "You need to inform the Cluster Type: kind, minikube or aks"
  echo ""
  echo "  Example:"
  echo ""
  echo "  ./run.sh kind"
  echo ""

  exit 1
fi

. "./${CLUSTER_TYPE?}-cluster-creation.sh"
. ./argocd-install.sh "${CLUSTER_TYPE?}"
. ./argocd-get-initial-password.sh
