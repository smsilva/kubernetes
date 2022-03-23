#!/bin/bash
ARGOCD_REPOSITORY_URL="git@github.com:smsilva/wasp-gitops.git"
ARGOCD_REPOSITORY_TYPE="git"
ARGOCD_REPOSITORY_NAME="wasp-gitops"
ARGOCD_REPOSITORY_PROJECT="default"

BASE64ENCODED_ARGOCD_REPOSITORY_URL=$(     echo -n "${ARGOCD_REPOSITORY_URL}"     | base64)
BASE64ENCODED_ARGOCD_REPOSITORY_TYPE=$(    echo -n "${ARGOCD_REPOSITORY_TYPE}"    | base64)
BASE64ENCODED_ARGOCD_REPOSITORY_NAME=$(    echo -n "${ARGOCD_REPOSITORY_NAME}"    | base64)
BASE64ENCODED_ARGOCD_REPOSITORY_PROJECT=$( echo -n "${ARGOCD_REPOSITORY_PROJECT}" | base64)
BASE64ENCODED_ARGOCD_REPOSITORY_PRIVATE_KEY=$(cat "${HOME}/.ssh/id_ed25519" | base64 | tr -d "\n")

kubectl -n argocd apply -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  annotations:
    managed-by: argocd.argoproj.io
  labels:
    argocd.argoproj.io/secret-type: repo-creds
    argocd.silvios.me/type: secret
  name: argocd-repo-creds-github
type: Opaque
data:
  sshPrivateKey: ${BASE64ENCODED_ARGOCD_REPOSITORY_PRIVATE_KEY}
  url: ${BASE64ENCODED_ARGOCD_REPOSITORY_URL}
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-repository-github
  annotations:
    managed-by: argocd.argoproj.io
  labels:
    argocd.argoproj.io/secret-type: repository
    argocd.silvios.me/type: secret
type: Opaque
data:
  name: ${BASE64ENCODED_ARGOCD_REPOSITORY_NAME}
  project: ${BASE64ENCODED_ARGOCD_REPOSITORY_PROJECT}
  type: ${BASE64ENCODED_ARGOCD_REPOSITORY_TYPE}
  url: ${BASE64ENCODED_ARGOCD_REPOSITORY_URL}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-ssh-known-hosts-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  ssh_known_hosts: |
    # github.com:22 SSH-2.0-babeld-e47cd09f
    github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
    # github.com:22 SSH-2.0-babeld-e47cd09f
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    # github.com:22 SSH-2.0-babeld-e47cd09f
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    # github.com:22 SSH-2.0-babeld-e47cd09f
    # github.com:22 SSH-2.0-babeld-e47cd09f
    # ssh.dev.azure.com:22 SSH-2.0-SSHBlackbox.10
    ssh.dev.azure.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJOfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgzIZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyNLHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBmly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H
    # ssh.dev.azure.com:22 SSH-2.0-SSHBlackbox.10
    # ssh.dev.azure.com:22 SSH-2.0-SSHBlackbox.10
    # ssh.dev.azure.com:22 SSH-2.0-SSHBlackbox.10
    # ssh.dev.azure.com:22 SSH-2.0-SSHBlackbox.10
    # vs-ssh.visualstudio.com:22 SSH-2.0-SSHBlackbox.10
    vs-ssh.visualstudio.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJOfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgzIZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyNLHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBmly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H
    # vs-ssh.visualstudio.com:22 SSH-2.0-SSHBlackbox.10
    # vs-ssh.visualstudio.com:22 SSH-2.0-SSHBlackbox.10
    # vs-ssh.visualstudio.com:22 SSH-2.0-SSHBlackbox.10
    # vs-ssh.visualstudio.com:22 SSH-2.0-SSHBlackbox.10
EOF

kubectl -n argocd apply -f - <<EOF
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: httpbin
  namespace: argocd
spec:
  destination:
    name: in-cluster
    namespace: httpbin
  project: default
  source:
    path: charts/httpbin
    repoURL: git@github.com:smsilva/wasp-gitops.git
    targetRevision: HEAD
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
