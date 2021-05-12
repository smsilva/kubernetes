#!/bin/bash

# Registering clusters to the environ
# https://cloud.google.com/anthos/docs/setup/cloud#registering_clusters_to_the_environ

. ../../load-config.sh

SERVICE_ACCOUNT_NAME="silvios"
SERVICE_ACCOUNT_JSON_FILE="service-account-${SERVICE_ACCOUNT_NAME?}.json"

gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME?} \
  --display-name="Service Account for Google Anthos"

# Creating service account keys
# https://cloud.google.com/iam/docs/creating-managing-service-account-keys#creating_service_account_keys

gcloud iam service-accounts keys create ${SERVICE_ACCOUNT_JSON_FILE?} \
  --iam-account=${SERVICE_ACCOUNT_NAME?}@${GCLOUD_PROJECT_ID?}.iam.gserviceaccount.com

gcloud projects add-iam-policy-binding ${GCLOUD_PROJECT_ID?} \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME?}@${GCLOUD_PROJECT_ID?}.iam.gserviceaccount.com" \
  --role="roles/owner"

gcloud projects add-iam-policy-binding ${GCLOUD_PROJECT_ID?} \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME?}@${GCLOUD_PROJECT_ID?}.iam.gserviceaccount.com" \
  --role="roles/gkehub.connect"

gcloud iam service-accounts add-iam-policy-binding \
  ${SERVICE_ACCOUNT_NAME?}@${GCLOUD_PROJECT_ID?}.iam.gserviceaccount.com \
  --member="serviceAccount:${GCLOUD_PROJECT_ID?}.svc.id.goog[cnrm-system/cnrm-controller-manager]" \
  --role="roles/iam.workloadIdentityUser"

cat <<EOF > configconnector.yaml
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  # the name is restricted to ensure that there is only one
  # ConfigConnector resource installed in your cluster
  name: configconnector.core.cnrm.cloud.google.com
spec:
  mode: cluster
  googleServiceAccount: "${SERVICE_ACCOUNT_NAME?}@${GCLOUD_PROJECT_ID?}.iam.gserviceaccount.com"
EOF

kubectl apply -f configconnector.yaml

kubectl create namespace configconnector

kubectl annotate namespace configconnector cnrm.cloud.google.com/project-id=${GCLOUD_PROJECT_ID?}

kubectl wait \
  --namespace cnrm-system \
  --for condition=Ready pod \
  --all

# Registering clusters to the environ
# https://cloud.google.com/anthos/docs/setup/cloud#registering_clusters_to_the_environ

gcloud container hub memberships register ${GKE_CLUSTER_NAME?}\
  --gke-cluster=${GKE_CLUSTER_ZONE?}/${GKE_CLUSTER_NAME?} \
  --service-account-key-file=${PWD?}/${SERVICE_ACCOUNT_JSON_FILE?}

gcloud container hub memberships list --format json
