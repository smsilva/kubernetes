#!/bin/bash

if ! which minikube > /dev/null; then
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube && \
  sudo mkdir -p /usr/local/bin/ && \
  sudo mv minikube /usr/local/bin/
else
  MINIKUBE_INSTALLED_VERSION=$(minikube version --short | awk '{ print $3 }')
  echo "minikube ${MINIKUBE_INSTALLED_VERSION} version currently installed"
fi
