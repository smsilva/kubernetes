#!/bin/bash

argocd_url=localhost:32080
argocd_initial_password=$(kubectl \
  --namespace argocd \
  get secret argocd-initial-admin-secret \
  --output jsonpath="{.data.password}" \
| base64 --decode)

echo "" && \
echo "argocd_url...............: ${argocd_url}" && \
echo "argocd_initial_password..: ${argocd_initial_password:0:5}"

argocd login \
  ${argocd_url} \
  --username "admin" \
  --password "${argocd_initial_password}" \
  --insecure
