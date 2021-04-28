#!/bin/bash

ARGOCD_URL=$(minikube service argocd-server -n argocd --url | grep 32443 | sed "s/http:\/\///")
ARGOCD_INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "" && \
echo "ARGOCD_URL...............: ${ARGOCD_URL}" && \
echo "ARGOCD_INITIAL_PASSWORD..: ${ARGOCD_INITIAL_PASSWORD}"

argocd login \
  ${ARGOCD_URL} \
  --username "admin" \
  --password "${ARGOCD_INITIAL_PASSWORD}" \
  --insecure
