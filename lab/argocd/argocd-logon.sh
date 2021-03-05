#!/bin/bash

ARGOCD_URL=$(minikube service argocd-server -n argocd --url | grep 32443 | sed "s/http:\/\///")
ARGOCD_INITIAL_PASSWORD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d '/' -f 2)

echo "" && \
echo "ARGOCD_URL...............: ${ARGOCD_URL}" && \
echo "ARGOCD_INITIAL_PASSWORD..: ${ARGOCD_INITIAL_PASSWORD}"

argocd login \
  ${ARGOCD_URL} \
  --username "admin" \
  --password "${ARGOCD_INITIAL_PASSWORD}" \
  --insecure
