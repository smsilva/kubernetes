#!/bin/bash
. ./check-environment-variables.sh

sudo sed -i "/.*${DOMAIN_NAME}.*/ d" /etc/hosts

for SERVER in $(echo {haproxy,nginx,foo,bar}.${DOMAIN_NAME}); do
  echo "${IP_LOADBALANCER} ${SERVER}" | sudo tee -a /etc/hosts
done
