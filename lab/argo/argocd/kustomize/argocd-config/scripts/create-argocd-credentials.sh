#!/bin/bash

export KUBERNETES_NAME="$(                   terraform output -raw name                   | base64 )"
export KUBERNETES_API_SERVER_URL="$(         terraform output -raw api_server             | base64 )"
export KUBERNETES_API_SERVER_TOKEN="$(       terraform output -raw api_token              )"
export KUBERNETES_CLUSTER_CA_CERTIFICATE="$( terraform output -raw cluster_ca_certificate )"

export KUBERNETES_CONFIG=$(cat <<EOF
   {
      "bearerToken": "${KUBERNETES_API_SERVER_TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${KUBERNETES_CLUSTER_CA_CERTIFICATE}"
      }
   }
EOF
)

export KUBERNETES_CONFIG_BASE64=$(echo ${KUBERNETES_CONFIG} | base64 | tr -d "\n")

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-cluster-credentials
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
data:
  name: ${KUBERNETES_NAME}
  server: ${KUBERNETES_API_SERVER_URL}
  config: |
    ${KUBERNETES_CONFIG_BASE64}
EOF
