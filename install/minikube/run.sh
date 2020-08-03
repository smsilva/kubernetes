#!/bin/bash
export MINIKUBE_IN_STYLE=false
minikube start \
  --kubernetes-version v1.17.7 \
  --driver=docker \
  --network-plugin=cni

kubectl config use-context minikube

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml  