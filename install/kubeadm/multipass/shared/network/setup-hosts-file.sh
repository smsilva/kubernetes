#!/bin/bash
set -e

DOMAIN_NAME=$1
IPV4_ADDRESS=$(ip -4 a | grep 'ens4:' -A1 | tail -1 | awk '{ print $2 }' | awk -F "/" '{ print $1 }')

echo "HOSTNAME.........: ${HOSTNAME}"
echo "DOMAIN_NAME......: ${DOMAIN_NAME}"
echo "IPV4_ADDRESS.....: ${IPV4_ADDRESS}"

sed -e "s/.*${HOSTNAME}.*/${IPV4_ADDRESS} ${HOSTNAME} ${HOSTNAME}.${DOMAIN_NAME} ${HOSTNAME}.local/" -i /etc/hosts

hostnamectl set-hostname "${HOSTNAME}.${DOMAIN_NAME}"
