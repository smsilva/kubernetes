#!/bin/bash

. ./load-config.sh

eksctl get cluster

eksctl delete cluster \
  --name ${EKS_CLUSTER_NAME?}
  --region ${EKS_CLUSTER_REGION?}
