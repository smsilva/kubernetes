#!/bin/bash
set -e

IFNAME=$1
DOMAIN_NAME=$2

echo "IFNAME...........: ${IFNAME}"
echo "DOMAIN_NAME......: ${DOMAIN_NAME}"

ADDRESS="$(ip -4 addr show ${IFNAME} | grep "inet" | head -1 | awk '{ print $2 }' | cut -d/ -f1)"
ADDRES_START=$(echo ${ADDRESS} | awk -F '.' '{ print $1 "." $2 "." $3 }')

echo "ADDRESS..........: ${ADDRESS}" && \
echo "ADDRES_START.....: ${ADDRES_START}" && \
echo "HOSTNAME.........: ${HOSTNAME}"

sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.${DOMAIN_NAME} ${HOSTNAME}.local/" -i /etc/hosts

hostnamectl set-hostname ${HOSTNAME}.${DOMAIN_NAME}
