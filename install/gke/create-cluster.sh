#!/bin/bash

# Creating a zonal cluster
# https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster

. ./load-config.sh

gcloud container clusters create ${GKE_CLUSTER_NAME?} \
  --num-nodes 1 \
  --enable-autoscaling \
  --enable-stackdriver-kubernetes \
  --addons ConfigConnector \
  --workload-pool=${GCLOUD_PROJECT_ID?}.svc.id.goog \
  --min-nodes 1 \
  --max-nodes 3 \
  --release-channel ${GKE_CLUSTER_RELEASE_CHANNEL?} \
  --zone ${GKE_CLUSTER_ZONE?} \
  --node-locations ${GKE_CLUSTER_NODE_LOCATIONS?}
