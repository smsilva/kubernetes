#!/bin/bash
SCRIPT_DIRECTORY="$(dirname $0)"

CLUSTER_NAME="${1-none}"

export LOCAL_TERRAFORM_VARIABLES_DIRECTORY="${PWD}/${SCRIPT_DIRECTORY}"
export STACK_INSTANCE_NAME=${CLUSTER_NAME}

env \
  DEBUG=1 \
  stackrun silviosilva/azure-kubernetes-cluster:3.4.0 destroy -auto-approve \
    -var-file=/opt/variables/wasp-cluster.auto.tfvars  \
    -var-file=/opt/variables/${CLUSTER_NAME}.auto.tfvars
