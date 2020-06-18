#!/bin/bash
. ./check-environment-variables.sh

for SERVER in ${SERVERS}; do
  SERVER_PREFIX_KEY_NAME=$(awk -F '-' '{ print $1 }' <<< "${SERVER}")

  SERVER_MEMORY_KEY="${SERVER_PREFIX_KEY_NAME^^}_MEMORY"
  SERVER_CPU_COUNT_KEY="${SERVER_PREFIX_KEY_NAME^^}_CPU_COUNT"
  SERVER_DISK_SIZE_KEY="${SERVER_PREFIX_KEY_NAME^^}_DISK_SIZE"

  echo "${SERVER}.${DOMAIN_NAME} (vcpu: ${!SERVER_CPU_COUNT_KEY} / mem: ${!SERVER_MEMORY_KEY} / disk: ${!SERVER_DISK_SIZE_KEY})"

  multipass launch \
    --cpus "${!SERVER_CPU_COUNT_KEY}" \
    --disk "${!SERVER_DISK_SIZE_KEY}" \
    --mem "${!SERVER_MEMORY_KEY}" \
    --name "${SERVER}" \
    --cloud-init "${CLOUD_INIT_TARGET_DIRECTORY}/${SERVER}.yaml" && \
  multipass mount "shared/" "${SERVER}":"/shared"
done
