#!/bin/bash
. ./check-environment-variables.sh

for SERVER in ${SERVERS}; do
  SERVER_IP=$(multipass info ${SERVER} | grep -E "^IPv4:" | awk '{ print $2 }')

  multipass exec ${SERVER} -- sudo sed \
    -e "/${SERVER}/d" \
    -e "2i${SERVER_IP} ${SERVER} ${SERVER}.${DOMAIN_NAME} ${SERVER}.local" \
    -e "3i127.0.0.1 localhost" \
    -i /etc/hosts

  multipass exec ${SERVER} -- sudo hostnamectl set-hostname "${SERVER}.${DOMAIN_NAME}"
done
