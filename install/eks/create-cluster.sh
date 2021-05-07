#!/bin/bash

. ./load-config.sh

eksctl get cluster

EKS_CLUSTER_NAME="silvios-dev"
EKS_CLUSTER_REGION="us-east-2"

eksctl create cluster \
--name ${EKS_CLUSTER_NAME?} \
--region ${EKS_CLUSTER_REGION?} \
--with-oidc \
--ssh-access \
--ssh-public-key ~/.ssh/id_rsa.pub \
--managed
