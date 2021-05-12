#!/bin/bash

set -e

CLUSTER_TYPE=$1

if [[ -z "${CLUSTER_TYPE}" ]]; then
  echo "You need to inform the Cluster Type: kind, minikube or aks"
  echo ""
  echo "  Example:"
  echo ""
  echo "  ./run.sh kind"
  echo ""

  exit 1
fi

. ./${CLUSTER_TYPE?}-cluster-creation.sh
. ./argocd-install.sh ${CLUSTER_TYPE?}
. ./install-ngninx-ingress-controller.sh

ARGOCD_INITIAL_PASSWORD=$(kubectl \
  --namespace argocd \
  get secret argocd-initial-admin-secret \
  --output jsonpath="{.data.password}" | base64 -d)

echo ""
echo "  1. Open a new Terminal and run a port-forward command:"
echo ""
echo "    kubectl --namespace argocd port-forward svc/argocd-server 8443:443"
echo ""
echo "  2. Copy the Password for admin user:"
echo ""
echo "    ${ARGOCD_INITIAL_PASSWORD}"
echo ""
echo "  3. Open the addres bellow in a browser:"
echo ""
echo "    https://localhost:8443"
echo ""
echo "  4. Create a new ArgoCD Application:"
echo ""
echo "    kubectl apply -f apps/httpbin"
echo ""
echo "  5. Wait for the httpbin POD become Ready and them test:"
echo ""
echo "    kubectl \\"
echo "      --namespace dev \\"
echo "      wait \\"
echo "      --for condition=Ready pod \\"
echo "      --selector app=httpbin && \\"
echo "    sleep 5 && \\"
echo "    curl \\"
echo "      --include \\"
echo "      --insecure \\"
echo "      --header \"Host: app.example.com\" \\"
echo "      https://127.0.0.1/get"
echo ""
