#!/bin/bash
SCRIPT_DIRECTORY="$(dirname $0)"

CLUSTER_NAME="${1-wasp-na-sbx-a}"

export LOCAL_TERRAFORM_VARIABLES_DIRECTORY="${PWD}/${SCRIPT_DIRECTORY}"
export STACK_INSTANCE_NAME=${CLUSTER_NAME}

env \
  DEBUG=2 \
  stackrun silviosilva/azure-kubernetes-cluster:3.4.0 apply -auto-approve \
    -var-file=/opt/variables/wasp-cluster.auto.tfvars \
    -var-file=/opt/variables/${CLUSTER_NAME}.auto.tfvars

OUTPUT_JSON_FILE="${LOCAL_TERRAFORM_VARIABLES_DIRECTORY}/${CLUSTER_NAME}.output.json"

echo "${OUTPUT_JSON_FILE}"

env \
  DEBUG=0 \
  LOCAL_TERRAFORM_VARIABLES_DIRECTORY="${PWD}/${SCRIPT_DIRECTORY}" \
  stackrun silviosilva/azure-kubernetes-cluster:3.4.0 output -json > "${OUTPUT_JSON_FILE}"
