vault kv get -format=json secret/my-app/config
vault kv get -format=json secret/my-app/config-1

vault operator raft snapshot save raft.snap

vault kv put secret/my-app/config-1 \
  username='my-static-user-name-value' \
  password='my-static-password-value'

vault kv get -format=json secret/my-app/config
vault kv get -format=json secret/my-app/config-1

vault operator raft snapshot restore raft.snap

vault kv get -format=json secret/my-app/config
vault kv get -format=json secret/my-app/config-1
