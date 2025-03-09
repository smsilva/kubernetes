#!/bin/bash
. ./check-environment-variables.sh

mkdir -p shared/network

for SERVER in ${SERVERS?}; do
  IP_SERVER_KEY_NAME=$(echo IP_${SERVER^^} | sed 's/-/_/')
  export IP_SERVER=${!IP_SERVER_KEY_NAME}

  NETPLAN_TEMPLATE_FILE="shared/network/netplan-template-${SERVER?}.yaml"
  cat "templates/netplan.yaml" | envsubst > "${NETPLAN_TEMPLATE_FILE?}"

  SYSTEMD_RESOLVED_FILE="shared/network/systemd-resolved-${SERVER?}.conf"
  envsubst < templates/systemd-resolved.conf > "${SYSTEMD_RESOLVED_FILE?}"

  multipass exec ${SERVER?} -- sudo cp "/${NETPLAN_TEMPLATE_FILE?}" "/etc/netplan/60-${SERVER?}.yaml"
  multipass exec ${SERVER?} -- sudo chmod 600 "/etc/netplan/60-${SERVER?}.yaml"
  multipass exec ${SERVER?} -- sudo netplan apply

  multipass exec ${SERVER?} -- sudo mkdir --parents "/etc/systemd/resolved.conf.d/"
  multipass exec ${SERVER?} -- sudo cp "/${SYSTEMD_RESOLVED_FILE?}" "/etc/systemd/resolved.conf.d/60-${SERVER?}.conf"
  multipass exec ${SERVER?} -- sudo systemctl restart systemd-resolved
done
