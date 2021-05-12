#!/bin/bash

# Creating a zonal cluster
# https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster

. ./load-config.sh

gcloud container clusters create ${GKE_CLUSTER_NAME?} \
  --enable-autoscaling \
  --enable-stackdriver-kubernetes \
  --addons ConfigConnector \
  --workload-pool=${GCLOUD_PROJECT_ID?}.svc.id.goog \
  --num-nodes 1 \
  --min-nodes 1 \
  --max-nodes 5 \
  --enable-ip-alias \
  --max-pods-per-node 110 \
  --default-max-pods-per-node 110 \
  --release-channel ${GKE_CLUSTER_RELEASE_CHANNEL?} \
  --zone ${GKE_CLUSTER_ZONE?} \
  --node-locations ${GKE_CLUSTER_NODE_LOCATIONS?}
