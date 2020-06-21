#!/bin/bash
. ./check-environment-variables.sh

for SERVER in ${SERVERS}; do
  IP_SERVER_KEY_NAME=$(echo IP_${SERVER^^} | sed 's/-/_/')
  export IP_SERVER=${!IP_SERVER_KEY_NAME}

  NETPLAN_TEMPLATE_FILE="shared/network/netplan-template-${SERVER}.yaml"

  cat "templates/netplan.yaml" | envsubst > "${NETPLAN_TEMPLATE_FILE}"

  multipass exec ${SERVER} -- sudo cp "/${NETPLAN_TEMPLATE_FILE}" "/etc/netplan/60-${SERVER}.yaml"
  multipass exec ${SERVER} -- sudo netplan apply 
done
