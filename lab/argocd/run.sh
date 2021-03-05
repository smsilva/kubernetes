#!/bin/bash
./01-minikube-cluster-creation.sh
./02-argocd-install.sh

ARGOCD_INITIAL_PASSWORD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d '/' -f 2)

echo ""
echo "   minikube service argocd-server -n argocd"
echo ""
echo "   User.....: admin"
echo "   Password.: ${ARGOCD_INITIAL_PASSWORD}"
echo ""
echo "   kubectl apply -f apps/nginx"
echo ""
