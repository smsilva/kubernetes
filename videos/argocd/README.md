# ArgoCD

##  1. k3d Cluster

```bash
k3d cluster create \
  --api-port 6550 \
  --port "9080:80@loadbalancer" \
  --port "9443:443@loadbalancer" \
  --port "32080:80@loadbalancer" \
  --servers 1 \
  --k3s-arg '--disable=traefik@server:*'

kubectl wait node \
  --selector kubernetes.io/os=linux \
  --for condition=Ready

kubectl wait deployment metrics-server \
  --namespace kube-system \
  --for condition=Available \
  --timeout=360s; sleep 2

kubectl wait pods \
  --namespace kube-system \
  --selector k8s-app=metrics-server \
  --for condition=Ready \
  --timeout=360s
```

##  2. Install

```bash
helm repo add argo https://argoproj.github.io/argo-helm

helm repo update argo

helm search repo argo/argo-cd

helm install \
  --namespace argocd \
  --create-namespace \
  argocd argo/argo-cd \
  --values "values/service.yaml" \
  --wait

cat <<EOF > /tmp/argocd.conf
export ARGOCD_USERNAME="admin"
export ARGOCD_PASSWORD="$(
  kubectl get secret argocd-initial-admin-secret \
    --namespace argocd \
    --output jsonpath="{.data.password}" \
  | base64 -d
)"
export ARGOCD_URL="http://localhost:32080"
clear
echo ARGOCD_USERNAME.....: \${ARGOCD_USERNAME}
echo ARGOCD_PASSWORD.....: \${ARGOCD_PASSWORD}
echo ARGOCD_URL..........: \${ARGOCD_URL}
EOF

source /tmp/argocd.conf
```
