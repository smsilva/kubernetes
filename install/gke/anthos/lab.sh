#!/bin/bash

# Registering clusters to the environ
# https://cloud.google.com/anthos/docs/setup/cloud#registering_clusters_to_the_environ

. ../../load-config.sh

gcloud projects list

GCLOUD_PROJECT_ID=$(gcloud projects list | grep ${GCLOUD_PROJECT_NAME?} | awk '{ print $1 }')

# Enable Cloud Operations for GKE
gcloud container clusters update ${GKE_CLUSTER_NAME?} \
  --enable-stackdriver-kubernetes

# Enabling Workload Identity on a cluster
# https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#enable_on_cluster
gcloud container clusters update ${GKE_CLUSTER_NAME?} \
  --workload-pool=${GCLOUD_PROJECT_ID?}.svc.id.goog

gcloud container node-pools list \
  --cluster ${GKE_CLUSTER_NAME?}

# Modify an existing node pool to enable GKE_METADATA. This update succeeds only if Workload Identity is enabled on the cluster. It immediately enables Workload Identity for workloads deployed to the node pool.
# https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#option_2_node_pool_modification
gcloud container node-pools update default-pool \
  --workload-metadata=GKE_METADATA \
  --cluster ${GKE_CLUSTER_NAME?}

gcloud container clusters update ${GKE_CLUSTER_NAME?} \
  --update-addons ConfigConnector=ENABLED

SERVICE_ACCOUNT_NAME="silvios"

gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME?}

# Creating service account keys
# https://cloud.google.com/iam/docs/creating-managing-service-account-keys#creating_service_account_keys

gcloud iam service-accounts keys create key-file \
  --iam-account=${SERVICE_ACCOUNT_NAME?}@${GCLOUD_PROJECT_ID?}.iam.gserviceaccount.com

jq -r .private_key key-file > ${SERVICE_ACCOUNT_NAME?}.key

gcloud projects add-iam-policy-binding ${GCLOUD_PROJECT_ID?} \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME?}@${GCLOUD_PROJECT_ID?}.iam.gserviceaccount.com" \
  --role="roles/owner"

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

kubectl create namespace config-connector

kubectl annotate namespace config-connector cnrm.cloud.google.com/project-id=${GCLOUD_PROJECT_ID?}

kubectl wait \
  --namespace cnrm-system \
  --for=condition=Ready pod \
  --all

# Registering clusters to the environ
# https://cloud.google.com/anthos/docs/setup/cloud#registering_clusters_to_the_environ

gcloud container hub memberships register ${GKE_CLUSTER_NAME?}\
  --gke-cluster=${GKE_CLUSTER_ZONE?}/${GKE_CLUSTER_NAME?} \
  --service-account-key-file=./${SERVICE_ACCOUNT_NAME?}.key
