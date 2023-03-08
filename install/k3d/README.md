# k3d

## Install

```bash
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

## Create Cluster

```bash
k3d cluster create \
  --api-port 6550 \
  --port "8081:80@loadbalancer" \
  --agents 2
```

## Exposing a Service

```bash
kubectl create deployment nginx --image=nginx

kubectl create service clusterip nginx --tcp=80:80

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
    - http:
        paths:
          - path: /
              pathType: Prefix
              backend:
              service:
                  name: nginx
                  port:
                  number: 80
EOF

curl -i http://localhost:8081
```

## Delete Cluster

```bash
k3d cluster delete
```
