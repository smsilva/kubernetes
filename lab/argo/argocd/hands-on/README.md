# ArgoCD

## Kind Cluster Creation

```bash
kind get clusters

kind create cluster \
  --image "kindest/node:v1.24.7" \
  --config "./kind/cluster.yaml"

kubectl get nodes
```

## ArgoCD Install

### Helm Repository Configuration

```bash
helm repo add argo https://argoproj.github.io/argo-helm

helm repo update argo

helm repo list

helm search repo argo

helm search repo argo/argo-cd

kubectl api-resources | grep argo
```

### Helm Chart Install

```bash
watch -n 3 'kubectl -n argocd get deployments,pods'

helm install \
  --namespace argocd \
  --create-namespace \
  argocd argo/argo-cd \
  --values "values/service.yaml" \
  --wait

helm list -n argocd

kubectl api-resources | grep argo
```

### Get ArgoCD admin initial password

```bash
./get-initial-password
```

### Create an ArgoCD Application using UI

```bash
watch -n 3 'kubectl -n argocd get applications -o wide; echo; kubectl -n demo get deployments; echo; kubectl -n demo get pods,services -o wide'

# Public
# https://github.com/smsilva/wasp-gitops.git
```

### Create an ArgoCD Application using kubectl

```bash
kubectl get applications httpbin \
  --namespace argocd \
  --output yaml \
| kubectl neat \
| tee "applications/httpbin.yaml"

kubectl apply \
  --namespace argocd \
  --filename "applications/httpbin.yaml"

kubectl delete application httpbin \
  --namespace argocd
```

### Acessing a Private Repository

```bash
# GitHub
# git@github.com:smsilva/wasp-gitops.git

kubectl describe application httpbin \
  --namespace argocd

kubectl get secrets \
  --namespace argocd \
  --label-columns=argocd.argoproj.io/secret-type

kubectl get secrets \
  --namespace argocd \
  --selector argocd.argoproj.io/secret-type=repo-creds

# Azure DevOps
# git@ssh.dev.azure.com:v3/smsilva/azure-platform/gitops
```

### CLI Install

```bash
ARGOCD_BINARY_LOCATION="${HOME}/bin/"
ARGOCD_BINARY_CANONICAL_PATH="${ARGOCD_BINARY_LOCATION?}/argocd"

mkdir -p "${ARGOCD_BINARY_LOCATION?}"

# put this line into your ${HOME}/.bashrc file if needed
export PATH=${ARGOCD_BINARY_LOCATION?}:${PATH}

ARGOCD_BINARY_LATEST_VERSION=$(
  curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" \
  | grep '"tag_name"' \
  | awk -F '"' '{ print $4 }'
)

curl \
  --show-error \
  --location \
  --output "${ARGOCD_BINARY_CANONICAL_PATH?}" \
  https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_BINARY_LATEST_VERSION?}/argocd-linux-amd64

chmod +x "${ARGOCD_BINARY_CANONICAL_PATH?}"

argocd version --short --client
```

### Managing Local Users and RBAC

```bash
ARGOCD_ADMIN_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
  --namespace argocd \
  --output jsonpath="{.data.password}" \
| base64 -d)

argocd login \
  --username admin \
  --password "${ARGOCD_ADMIN_PASSWORD?}" \
  --insecure localhost:32080 

# User Management: Local users/accounts
# https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#local-usersaccounts-v15

argocd account list

helm upgrade \
  --install \
  --namespace argocd \
  --create-namespace \
  argocd argo/argo-cd \
  --values "values/configs-cm-users.yaml" \
  --values "values/configs-rbac.yaml" \
  --values "values/service.yaml" \
  --wait

argocd account update-password \
  --account alice \
  --current-password "${ARGOCD_ADMIN_PASSWORD?}" \
  --new-password "Lonely ghost 37"

# RBAC Configuration
# https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac

argocd admin settings rbac validate \
  --policy-file "values/policy.csv"

argocd admin settings rbac \
  can alice override applications 'default/*' \
  --policy-file values/policy.csv

argocd admin settings rbac \
  can alice update applications 'default/*' \
  --policy-file values/policy.csv

argocd admin settings rbac \
  can alice sync applications 'default/*' \
  --policy-file values/policy.csv
```

### Deploying to another Cluster

```bash
argocd cluster add wasp-sandbox-xt56
```

### Kind Cluster Delete

```bash
kind delete clusters --all
```
