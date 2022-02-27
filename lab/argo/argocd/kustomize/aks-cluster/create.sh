#!/bin/bash
SCRIPT_DIRECTORY="$(dirname $0)"

CLUSTER_NAME="${1-wasp-na-sbx-a}"

env \
  DEBUG=1 \
  LOCAL_TERRAFORM_VARIABLES_DIRECTORY="${PWD}/${SCRIPT_DIRECTORY}" \
  STACK_INSTANCE_NAME=${CLUSTER_NAME} \
  stackrun silviosilva/azure-kubernetes-cluster:3.3.0 apply -auto-approve \
    -var-file=/opt/variables/terraform.tfvars \
    -var-file=/opt/variables/${CLUSTER_NAME}.auto.tfvars

OUTPUT_JSON_FILE="${LOCAL_TERRAFORM_VARIABLES_DIRECTORY}/${CLUSTER_NAME}.output.json"

env \
  DEBUG=0 \
  LOCAL_TERRAFORM_VARIABLES_DIRECTORY="${PWD}/${SCRIPT_DIRECTORY}" \
  STACK_INSTANCE_NAME=${CLUSTER_NAME} \
  stackrun silviosilva/azure-kubernetes-cluster:3.3.0 output -json > "${OUTPUT_JSON_FILE}"
