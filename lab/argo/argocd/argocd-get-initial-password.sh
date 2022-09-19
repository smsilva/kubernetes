#!/bin/bash
ARGOCD_INITIAL_PASSWORD=$(kubectl \
  --namespace argocd \
  get secret argocd-initial-admin-secret \
  --output jsonpath="{.data.password}" | base64 -d)

cat <<EOF

1. Copy the Password for admin user:

  ${ARGOCD_INITIAL_PASSWORD}

2. Open the address bellow in a browser:

  http://localhost:32080

4. Create a new ArgoCD Application:

  kubectl apply -f apps/httpbin

5. Wait for the httpbin POD become Ready and them test:

  kubectl \\
    --namespace default \\
    wait \\
    --for condition=Ready pod \\
    --selector app=httpbin \\
    --timeout=360s && \\
  sleep 5 && \\
  curl \\
    --include \\
    --insecure \\
    --header "Host: httpbin.example.com" \\
    https://127.0.0.1/get

6. (Optional) Open a new Terminal and run a port-forward command:

  kubectl \\
    --namespace argocd \\
    port-forward svc/argocd-server 8080:443 \\
    --context=kind-argocd

7. (Optional) Open the address bellow in a browser:

  http://localhost:8080

EOF
