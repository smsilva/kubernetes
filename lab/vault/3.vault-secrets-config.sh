vault secrets enable -path=secret kv-v2

vault kv put secret/my-app/database \
  username='my-static-user-name-value' \
  password='my-static-password-value'

vault kv put secret/my-app/cache \
  token='my-static-user-name-value'

vault kv list secret/my-app

vault kv get -format=yaml secret/my-app/database
vault kv get -format=yaml secret/my-app/cache
