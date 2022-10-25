#!/bin/bash
ARGOCD_INITIAL_PASSWORD=$(kubectl \
  --namespace argocd \
  get secret argocd-initial-admin-secret \
  --output jsonpath="{.data.password}" | base64 -d)

cat <<EOF

1. Copy ArgoCD Initial Credentials:

  user:     admin
  password: ${ARGOCD_INITIAL_PASSWORD}
  url:      http://localhost:32080

2. Create a new ArgoCD Application:

  kubectl create --filename apps/httpbin.yaml

  kubectl \\
    --namespace httpbin \\
    get deploy,replicasets,pods,services,endpoints \\
    --output wide

3. (Optional) Open a new Terminal and run a port-forward command:

  kubectl \\
    --namespace argocd \\
    port-forward svc/argocd-server 8080:443 \\
    --context=kind-argocd

3.1. Open the address bellow in a browser:

  http://localhost:8080

4. Notifications logs

  kubectl \\
    --namespace argocd \\
    logs -f -l app.kubernetes.io/component=notifications-controller

EOF
