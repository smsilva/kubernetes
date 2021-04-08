cat <<EOF | kubectl --namespace default apply --filename=-
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
---
apiVersion: v1
kind: Pod
metadata:
  name: app
  annotations:
    vault.hashicorp.com/role: "my-app"
    vault.hashicorp.com/agent-pre-populate-only: "true"
    vault.hashicorp.com/agent-init-first: "true"
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/agent-inject-secret-credentials.yaml: "secret/data/my-app/config"
    vault.hashicorp.com/agent-inject-template-credentials.yaml: |
      {{- with secret "secret/data/my-app/config" -}}
      connection:
        username:"{{ .Data.data.username }}"
        password:"{{ .Data.data.password }}"
      {{- end -}}
spec:
  serviceAccountName: my-app
  containers:
  - name: app
    image: silviosilva/utils
    command: ["/bin/sh"]
    args: ["-c", "while true; do sleep 500; done"]
  restartPolicy: OnFailure
EOF

kubectl logs app -c vault-agent-init

kubectl exec app -c app -- cat /vault/secrets/credentials.yaml
