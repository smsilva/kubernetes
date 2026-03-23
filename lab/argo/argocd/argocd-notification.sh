#!/bin/bash
kubectl_patch() {
  keypair_data=$1
  temporary_patch_file=$(mktemp)

cat <<EOF > "${temporary_patch_file?}"
stringData:
  ${keypair_data}
EOF

  kubectl \
    --namespace argocd \
    patch secret argocd-notifications-secret \
    --patch-file="${temporary_patch_file?}"
}

if [ -n "${TELEGRAM_BOT_TOKEN}" ]; then
  kubectl_patch "telegram-token: ${TELEGRAM_BOT_TOKEN}"
fi

printenv \
| grep "^GOOGLE_CHAT_WEBHOOK_URL_" \
| while read -r key_value; do
  key=$(awk -F "=" '{ print $1 }' <<< "${key_value}" | tr '[:upper:]' '[:lower:]')
  value=$(sed 's/^[^=]*=//' <<< "${key_value}")

  kubectl_patch "${key//_/-}: ${value}"
done
