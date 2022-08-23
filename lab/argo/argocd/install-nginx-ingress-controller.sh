#!/bin/bash

echo "Installing NGINX Ingress Controller"

kubectl apply \
  --filename https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml

kubectl wait \
  --namespace ingress-nginx \
  --for condition=ready pod \
  --selector app.kubernetes.io/component=controller \
  --timeout=360s

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  annotations:
    ingress.kubernetes.io/rewrite-target: "/"
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              service:
                name: httpbin
                port:
                  number: 80
EOF

# kubectl get ingress nginx

# kubectl describe ingress nginx

sleep 10

curl -ik --header "Host: app.example.com" https://127.0.0.1/get

# curl -ik https://app.example.com/get

# curl -ik https://app.example.com/test
