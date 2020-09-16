#!/bin/bash

# Check if Minikube is Installed
if ! which minikube > /dev/null; then
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube && \
  sudo mkdir -p /usr/local/bin/ && \
  sudo mv minikube /usr/local/bin/
else
  MINIKUBE_INSTALLED_VERSION=$(minikube version --short | awk '{ print $3 }')
  echo "minikube ${MINIKUBE_INSTALLED_VERSION} version currently installed"
fi

# Retrieve lastest Kubernetes Version
KUBERNETES_BASE_VERSION=$(apt-cache madison kubeadm | head -1 | awk -F '|' '{ print $2 }' | tr -d ' ')
KUBERNETES_VERSION="${KUBERNETES_BASE_VERSION%-*}"

# Check if there isn't a minikube context created
if ! kubectl config get-contexts minikube > /dev/null; then
  # Start Minikube using Docker Driver
  export MINIKUBE_IN_STYLE=false && \
  minikube start \
    --kubernetes-version "v${KUBERNETES_VERSION}" \
    --driver=docker \
    --network-plugin=cni

  # Configure minikube context as default context  
  kubectl config use-context minikube
  
  # Configure Weave CNI Plugin
  kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
  
  # Wait for Deployments in kube-system become ready
  for deploymentName in $(kubectl -n kube-system get deploy -o name); do
     echo "Waiting for: ${deploymentName}"
  
     kubectl \
       -n kube-system \
       wait \
       --for condition=available \
       --timeout=90s \
       ${deploymentName};
  done
fi
