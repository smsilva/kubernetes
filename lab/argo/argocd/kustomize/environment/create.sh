#!/bin/bash

export ENVIRONMENT_NAME="${1-wasp-sbx-na}"

env STACK_INSTANCE_NAME=${ENVIRONMENT_NAME} stackrun silviosilva/azure-wasp-foundation:0.1.0 apply -auto-approve -var="name=${ENVIRONMENT_NAME}"
