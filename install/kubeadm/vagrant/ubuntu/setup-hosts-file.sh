#!/bin/bash
set -e

SERVER_IP=$1
DOMAIN_NAME=$2
SERVER_NAME=$(hostname --short)

hostnamectl set-hostname "${SERVER_NAME}.${DOMAIN_NAME}" &> /dev/null

sed \
  -e "/127.0.0.1/d" \
  -e "2i127.0.0.1 localhost" \
  -e "/${SERVER_NAME}/d" \
  -e "2i${SERVER_IP} ${SERVER_NAME} ${SERVER_NAME}.${DOMAIN_NAME} ${SERVER_NAME}.local" \
  -i /etc/hosts

cat /etc/hosts
