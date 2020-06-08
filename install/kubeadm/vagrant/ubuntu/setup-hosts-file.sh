#!/bin/bash
set -e

IPV4_ADDRESS=$1
DOMAIN_NAME=$2

echo "HOSTNAME.........: ${HOSTNAME}"
echo "DOMAIN_NAME......: ${DOMAIN_NAME}"
echo "IPV4_ADDRESS.....: ${IPV4_ADDRESS}"

sed -e "s/^.*${HOSTNAME}.*/${IPV4_ADDRESS} ${HOSTNAME} ${HOSTNAME}.${DOMAIN_NAME} ${HOSTNAME}.local/" -i /etc/hosts

hostnamectl set-hostname "${HOSTNAME}.${DOMAIN_NAME}"

hostnamectl

cat /etc/hosts
