#!/bin/bash

export KUBERNETES_NAME="$(                   terraform output -raw name                   )"
export KUBERNETES_API_SERVER_URL="$(         terraform output -raw api_server             )"
export KUBERNETES_API_SERVER_TOKEN="$(       terraform output -raw api_token              )"
export KUBERNETES_CLUSTER_CA_CERTIFICATE="$( terraform output -raw cluster_ca_certificate )"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-cluster-credentials-${KUBERNETES_NAME}
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: ${KUBERNETES_NAME}
  server: ${KUBERNETES_API_SERVER_URL}
  config: |
    {
      "bearerToken": "${KUBERNETES_API_SERVER_TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${KUBERNETES_CLUSTER_CA_CERTIFICATE}"
      }
    }
EOF
