#!/bin/bash

sh ../argocd-logon.sh

kubectl create ns dev

argocd app create "nginx" \
  --repo "https://github.com/smsilva/argocd.git" \
  --path "nginx" \
  --dest-server "https://kubernetes.default.svc" \
  --dest-namespace "dev" \
  --sync-policy "automated" \
  --auto-prune \
  --self-heal

argocd app list

argocd app get nginx

argocd app wait nginx
