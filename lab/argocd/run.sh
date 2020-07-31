#!/bin/bash

kubectl config use-context minikube

kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64

sudo chmod +x /usr/local/bin/argocd

kubectl apply -n argocd -f argocd-server-service.yaml

ARGOCD_INITIAL_PASSWORD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d '/' -f 2)

argocd login \
  $(minikube service argocd-server -n argocd --url | grep 32443 | sed "s/http:\/\///") \
  --username admin \
  --password "${ARGOCD_INITIAL_PASSWORD}" \
  --insecure

argocd account update-password \
  --account admin \
  --current-password "${ARGOCD_INITIAL_PASSWORD}" \
  --new-password "MyStrongPassword"

argocd app create nginx \
  --repo https://github.com/smsilva/argocd-k8s-nginx.git \
  --path nginx \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev

argocd app list

argocd app get nginx

argocd app sync nginx

argocd app set nginx --sync-policy automated
argocd app set nginx --auto-prune
argocd app set nginx --self-heal
