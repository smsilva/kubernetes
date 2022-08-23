#!/bin/bash
GIT_REPOSITORY_GITHUB="git@github.com:smsilva"
GIT_REPOSITORY_AZURE_DEVOPS="git@ssh.dev.azure.com:v3/smsilva/azure-platform"

BASE64ENCODED_GIT_REPOSITORY_GITHUB="$(       echo ${GIT_REPOSITORY_GITHUB}       | base64)"
BASE64ENCODED_GIT_REPOSITORY_AZURE_DEVOPS="$( echo ${GIT_REPOSITORY_AZURE_DEVOPS} | base64)"
BASE64ENCODED_ARGOCD_REPOSITORY_PRIVATE_KEY=$(cat "${HOME}/.ssh/id_rsa" | base64 | tr -d "\n")

kubectl -n argocd apply -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  annotations:
    managed-by: argocd.argoproj.io
  labels:
    argocd.argoproj.io/secret-type: repo-creds
  name: argocd-repo-creds-github
type: Opaque
data:
  sshPrivateKey: ${BASE64ENCODED_ARGOCD_REPOSITORY_PRIVATE_KEY}
  url: ${BASE64ENCODED_GIT_REPOSITORY_GITHUB}
---
apiVersion: v1
kind: Secret
metadata:
  annotations:
    managed-by: argocd.argoproj.io
  labels:
    argocd.argoproj.io/secret-type: repo-creds
  name: argocd-repo-creds-azure-devops
type: Opaque
data:
  sshPrivateKey: ${BASE64ENCODED_ARGOCD_REPOSITORY_PRIVATE_KEY}
  url: ${BASE64ENCODED_GIT_REPOSITORY_AZURE_DEVOPS}
EOF

kubectl -n argocd apply -f - <<EOF
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-from-github
  namespace: argocd
spec:
  destination:
    name: in-cluster
    namespace: demo-from-github

  project: infra

  source:
    path: charts/httpbin
    repoURL: git@github.com:smsilva/helm.git
    targetRevision: main

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-from-azure-devops
  namespace: argocd
spec:
  destination:
    name: in-cluster
    namespace: demo-from-azure-devops

  project: infra

  source:
    path: charts/httpbin
    repoURL: git@ssh.dev.azure.com:v3/smsilva/azure-platform/gitops
    targetRevision: main

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
