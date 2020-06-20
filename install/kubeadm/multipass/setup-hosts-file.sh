#!/bin/bash
. ./check-environment-variables.sh

for SERVER in ${SERVERS}; do
  IPV4_ADDRESS=$(multipass info ${SERVER} | grep -E "^IPv4:" | awk '{ print $2 }')

  multipass exec ${SERVER} -- sudo sed -e "s/.*${SERVER}.*/${IPV4_ADDRESS} ${SERVER} ${SERVER}.${DOMAIN_NAME} ${SERVER}.local/" -i /etc/hosts
  multipass exec ${SERVER} -- sudo hostnamectl set-hostname "${SERVER}.${DOMAIN_NAME}"
  multipass exec ${SERVER} -- cat /etc/hosts
done
