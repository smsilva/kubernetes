#!/bin/bash
./check-environment-variables.sh

TARGET_DIRECTORY="cloud-init"
TEMPLATE_DIRECTORY="templates/cloud-init"

mkdir --parents "${TARGET_DIRECTORY}"

rm -rf "${TARGET_DIRECTORY}/*.yaml"

for SERVER in ${SERVERS}; do
  export SERVER_HOST_NAME="${SERVER}"
  
  CLOUD_INIT_TEMPLATE_NAME=$(awk -F '-' '{ print $1 }' <<< "${SERVER}")
  
  CLOUD_INIT_FILE="${TARGET_DIRECTORY}/${SERVER}.yaml"
  
  cat "${TEMPLATE_DIRECTORY}/${CLOUD_INIT_TEMPLATE_NAME}.yaml" | envsubst > "${CLOUD_INIT_FILE}"

  echo "${CLOUD_INIT_FILE}"
done
