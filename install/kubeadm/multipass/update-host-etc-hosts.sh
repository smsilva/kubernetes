#!/bin/bash
. ./check-environment-variables.sh

echo "IP_LOADBALANCER..: ${IP_LOADBALANCER}"

IP_LOADBALANCER_MULTIPASS=$(multipass list | grep -E "^loadbalancer" | awk '{ print $3 }')

sudo sed -i "/.*${DOMAIN_NAME}.*/ d" /etc/hosts

for SERVER in $(echo {haproxy,nginx,foo,bar}.${DOMAIN_NAME}); do
  echo "${IP_LOADBALANCER_MULTIPASS} ${SERVER}" | sudo tee -a /etc/hosts
done
