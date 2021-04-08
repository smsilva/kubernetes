vault policy write my-app-policy - <<EOF
path "secret/data/my-app/config" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/my-app \
  bound_service_account_names="*" \
  bound_service_account_namespaces="default" \
  policies="my-app-policy" \
  ttl=0
