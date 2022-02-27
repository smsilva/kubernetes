#!/bin/bash
SCRIPT_DIRECTORY="$(dirname $0)"

CLUSTER_NAME="${1-none}"

env \
  DEBUG=1 \
  LOCAL_TERRAFORM_VARIABLES_DIRECTORY="${PWD}/${SCRIPT_DIRECTORY}" \
  STACK_INSTANCE_NAME=${CLUSTER_NAME} \
  stackrun silviosilva/azure-kubernetes-cluster:3.3.0 destroy -auto-approve \
    -var-file=/opt/variables/terraform.tfvars \
    -var-file=/opt/variables/${CLUSTER_NAME}.auto.tfvars
