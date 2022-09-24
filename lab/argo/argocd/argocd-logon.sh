#!/bin/bash

ARGOCD_URL=localhost:32080
ARGOCD_INITIAL_PASSWORD=$(kubectl \
  --namespace argocd \
  get secret argocd-initial-admin-secret \
  --output jsonpath="{.data.password}" \
| base64 --decode)

echo "" && \
echo "ARGOCD_URL...............: ${ARGOCD_URL}" && \
echo "ARGOCD_INITIAL_PASSWORD..: ${ARGOCD_INITIAL_PASSWORD:0:5}"

argocd login \
  ${ARGOCD_URL} \
  --username "admin" \
  --password "${ARGOCD_INITIAL_PASSWORD}" \
  --insecure
