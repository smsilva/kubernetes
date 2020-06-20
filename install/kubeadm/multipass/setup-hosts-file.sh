#!/bin/bash
. ./check-environment-variables.sh

echo "Updating /etc/hosts file and Hostname"

for SERVER in ${SERVERS}; do
  IPV4_ADDRESS=$(multipass info ${SERVER} | grep -E "^IPv4:" | awk '{ print $2 }')

  echo "  ${SERVER}.${DOMAIN_NAME} (${IPV4_ADDRESS})"

  multipass exec ${SERVER} -- sudo sed -e "s/.*${SERVER}.*/${IPV4_ADDRESS} ${SERVER} ${SERVER}.${DOMAIN_NAME} ${SERVER}.local/" -i /etc/hosts
  multipass exec ${SERVER} -- sudo hostnamectl set-hostname "${SERVER}.${DOMAIN_NAME}"
  multipass exec ${SERVER} -- cat /etc/hosts

  echo ""
done
