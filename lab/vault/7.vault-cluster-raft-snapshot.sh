cat <<EOF > kind-cluster.yaml
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF

for CLUSTER in {primary,secondary}; do
  mkdir -p ${CLUSTER?}
  kind create cluster \
    --config kind-cluster.yaml \
    --name vault-${CLUSTER?} &
done

vault kv get -format=yaml secret/my-app/database
vault kv get -format=yaml secret/my-app/cache

vault operator raft snapshot save /home/vault/raft.snap

vault kv list secret/my-app

vault kv put secret/my-app/api \
  token='my-static-token-value'

exit

kubectl \
  --context kind-vault-primary \
  cp vault/vault-0:home/vault/raft.snap raft.snap

kubectl \
  --context kind-vault-secondary \
  --namespace vault \
  cp raft.snap vault/vault-0:home/vault/raft.snap

vault operator raft snapshot restore /home/vault/raft.snap
vault operator raft snapshot restore -force /home/vault/raft.snap

vault kv get -format=json secret/my-app/database
vault kv get -format=json secret/my-app/cache
