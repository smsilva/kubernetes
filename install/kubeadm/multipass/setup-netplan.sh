#!/bin/bash
. ./check-environment-variables.sh

for SERVER in ${SERVERS}; do
  SERVER_IP_KEY_NAME=$(echo IP_${SERVER^^} | sed 's/-/_/')
  SERVER_IP=${!SERVER_IP_KEY_NAME}

  cat "templates/netplan.yaml" | envsubst | sed "s/IP_SERVER/${SERVER_IP}/g" > "shared/network/netplan-template-${SERVER}.yaml"

  multipass exec ${SERVER} -- sudo cp "/shared/network/netplan-template-${SERVER}.yaml" "/etc/netplan/60-${SERVER}.yaml"
  multipass exec ${SERVER} -- ls /etc/netplan/
  multipass exec ${SERVER} -- sudo netplan apply 
done
