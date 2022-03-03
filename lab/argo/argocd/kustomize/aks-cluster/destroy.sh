#!/bin/bash
SCRIPT_DIRECTORY="$(dirname $0)"

CLUSTER_NAME="${1-none}"

export LOCAL_TERRAFORM_VARIABLES_DIRECTORY="${PWD}/${SCRIPT_DIRECTORY}"
export STACK_INSTANCE_NAME=${CLUSTER_NAME}

source ${LOCAL_TERRAFORM_VARIABLES_DIRECTORY}/image.conf

env \
  DEBUG=1 \
  stackrun ${AZURE_KUBERNETES_CLUSTER_IMAGE?} destroy -auto-approve \
    -var-file=/opt/variables/wasp-cluster.auto.tfvars  \
    -var-file=/opt/variables/${CLUSTER_NAME}.auto.tfvars
