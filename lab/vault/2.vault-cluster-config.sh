VAULT_KEY_FILE="vault-cluster-keys.json"

kubectl exec vault-0 -- vault operator init \
  -key-shares=1 \
  -key-threshold=1 \
  -format=json | tee ${VAULT_KEY_FILE?}

VAULT_UNSEAL_KEY=$(cat ${VAULT_KEY_FILE?} | jq -r ".unseal_keys_b64[]")

kubectl exec vault-0 -- vault operator unseal ${VAULT_UNSEAL_KEY?} && \
kubectl exec vault-0 -- vault status

kubectl exec vault-1 -- vault operator raft join http://vault-0.vault-internal:8200 && \
kubectl exec vault-1 -- vault operator unseal ${VAULT_UNSEAL_KEY?}
kubectl exec vault-1 -- vault status

kubectl exec vault-2 -- vault operator raft join http://vault-0.vault-internal:8200 && \
kubectl exec vault-2 -- vault operator unseal ${VAULT_UNSEAL_KEY?}
kubectl exec vault-2 -- vault status

cat ${VAULT_KEY_FILE?} | jq -r ".root_token" | clip && \
kubectl exec \
  --namespace vault \
  --stdin=true \
  --tty=true vault-0 -- /bin/sh

vault operator raft list-peers
