#!/bin/bash
#./00.kind-cluster-creation.sh
# ./01-minikube-cluster-creation.sh
./02-argocd-install.sh

ARGOCD_INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "   kubectl --namespace argocd port-forward svc/argocd-server 8443:443"
echo ""
echo "   http://localhost:8443"
echo ""
echo "   User.....: admin"
echo "   Password.: ${ARGOCD_INITIAL_PASSWORD}"
echo ""
echo "   kubectl apply -f apps/argo-rollouts"
echo "   kubectl apply -f apps/httpbin"
echo "   kubectl apply -f apps/vault"
echo ""
echo "   sudo sed -i '/app.example.com/d' /etc/hosts"
echo "   echo '127.0.0.1 app.example.com' | sudo tee -a /etc/hosts"
echo ""
echo "   curl -ks https://app.example.com/get"
echo ""
