#!/bin/bash
if ! [ -z "${TELEGRAM_BOT_TOKEN}" ]; then
cat <<EOF | kubectl -n argocd apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
stringData:
  telegram-token: ${TELEGRAM_BOT_TOKEN}
EOF
fi
