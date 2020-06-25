#!/bin/bash
. ./check-environment-variables.sh

if [ -z "${CLOUD_INIT_TARGET_DIRECTORY}" ]; then
  echo "You need to configure CLOUD_INIT_TARGET_DIRECTORY parameter in source environment.conf file."
  exit 1
fi

[ -e "${CLOUD_INIT_TARGET_DIRECTORY}" ] && rm -rf "${CLOUD_INIT_TARGET_DIRECTORY}"

mkdir --parents "${CLOUD_INIT_TARGET_DIRECTORY}"

for SERVER in ${SERVERS}; do
  export SERVER_HOST_NAME="${SERVER}"
  
  CLOUD_INIT_TEMPLATE_NAME=$(awk -F '-' '{ print $1 }' <<< "${SERVER}")
  
  CLOUD_INIT_FILE="${CLOUD_INIT_TARGET_DIRECTORY}/${SERVER}.yaml"
  
  cat "${CLOUD_INIT_TEMPLATE_DIRECTORY}/${CLOUD_INIT_TEMPLATE_NAME}.yaml" | envsubst > "${CLOUD_INIT_FILE}"
done
