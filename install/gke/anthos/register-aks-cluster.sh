#!/bin/bash

# Tutorial: Connect Amazon EKS and Azure AKS Clusters with Google Anthos
# https://thenewstack.io/tutorial-connect-amazon-eks-and-azure-aks-clusters-with-google-anthos/

gcloud services enable \
  anthos.googleapis.com \
  cloudresourcemanager.googleapis.com \
  container.googleapis.com \
  gkeconnect.googleapis.com \
  gkehub.googleapis.com \
  iamcredentials.googleapis.com \
  meshca.googleapis.com \
  meshconfig.googleapis.com \
  meshtelemetry.googleapis.com \
  monitoring.googleapis.com \
  runtimeconfig.googleapis.com

gcloud container hub config-management enable

gcloud container hub memberships register silvios-dev-eastus2-aks \
  --context=silvios-dev-eastus2 \
  --service-account-key-file=${PWD?}/${SERVICE_ACCOUNT_JSON_FILE?} \
  --kubeconfig=${HOME}/.kube/config \
  --project=${GCLOUD_PROJECT_ID?}

gcloud container hub memberships register silvios-dev-eastus2-aks \
  --context=silvios-dev-eastus2 \
  --kubeconfig=${HOME}/.kube/config \
  --service-account-key-file=${PWD?}/${SERVICE_ACCOUNT_JSON_FILE?}
