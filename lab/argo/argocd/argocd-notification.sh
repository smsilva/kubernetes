#!/bin/bash
if [ -n "${TELEGRAM_BOT_TOKEN}" ]; then
cat <<EOF | kubectl -n argocd apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
stringData:
  telegram-token: ${TELEGRAM_BOT_TOKEN}
EOF
fi

if [ -n "${GOOGLE_CHAT_WEBHOOK_URL_DEVOPS_TEAMS}" ]; then
cat <<EOF | kubectl -n argocd apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
stringData:
  google-chat-webhook-url-devops-team: ${GOOGLE_CHAT_WEBHOOK_URL_DEVOPS_TEAMS}
EOF
fi
