#!/bin/bash
kubectl_patch() {
  KEYPAIR_DATA=$1
  TEMPORARY_PATCH_FILE=$(mktemp)

cat <<EOF > "${TEMPORARY_PATCH_FILE?}"
stringData:
  ${KEYPAIR_DATA}
EOF

  kubectl \
    --namespace argocd \
    patch secret argocd-notifications-secret \
    --patch-file="${TEMPORARY_PATCH_FILE?}"
}

if [ -n "${TELEGRAM_BOT_TOKEN}" ]; then
  kubectl_patch "telegram-token: ${TELEGRAM_BOT_TOKEN}"
fi

printenv \
| grep "^GOOGLE_CHAT_WEBHOOK_URL_" \
| while read -r LINE; do
  KEY=$(awk -F "=" '{ print $1 }' <<< "${LINE}" | tr '[:upper:]' '[:lower:]')
  VALUE=$(sed 's/^[^=]*=//' <<< "${LINE}")

  kubectl_patch "${KEY//_/-}: ${VALUE}"
done
