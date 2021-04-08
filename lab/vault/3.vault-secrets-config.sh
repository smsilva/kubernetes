vault secrets enable -path=secret kv-v2

vault kv put secret/my-app/config \
  username='my-static-user-name-value' \
  password='my-static-password-value'

vault kv get -format=json secret/my-app/config
