#!/bin/bash
set -e

. ./check-environment-variables.sh

echo ""
echo "Creating Servers"
echo ""

for SERVER in ${SERVERS?}; do
  SERVER_PREFIX_KEY_NAME=$(awk -F '-' '{ print $1 }' <<< "${SERVER}")

  SERVER_MEMORY_KEY="${SERVER_PREFIX_KEY_NAME^^}_MEMORY"
  SERVER_CPU_COUNT_KEY="${SERVER_PREFIX_KEY_NAME^^}_CPU_COUNT"
  SERVER_DISK_SIZE_KEY="${SERVER_PREFIX_KEY_NAME^^}_DISK_SIZE"

  echo "${SERVER?}.${DOMAIN_NAME?} (vcpu: ${!SERVER_CPU_COUNT_KEY} / mem: ${!SERVER_MEMORY_KEY} / disk: ${!SERVER_DISK_SIZE_KEY})"

  if ! ./list.sh | grep -q -E ${SERVER?}; then
    multipass launch \
      --cpus "${!SERVER_CPU_COUNT_KEY}" \
      --disk "${!SERVER_DISK_SIZE_KEY}" \
      --mem "${!SERVER_MEMORY_KEY}" \
      --name "${SERVER?}" \
      --cloud-init "${CLOUD_INIT_TARGET_DIRECTORY?}/${SERVER?}.yaml" && \
    multipass mount "shared/" "${SERVER?}":"/shared"
  else
    STATE=$(multipass info "${SERVER?}" | sed -n '/^State/ p' | awk '{ print $2 }')

    if [ ${STATE} == "Stopped" ]; then
      multipass start "${SERVER?}"
    fi
  fi
  
  echo ""
done
