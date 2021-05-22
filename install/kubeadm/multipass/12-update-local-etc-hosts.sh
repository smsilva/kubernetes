#!/bin/bash
. ./check-environment-variables.sh

sudo sed -i "/.*${DOMAIN_NAME?}.*/ d" /etc/hosts

for SERVER in {haproxy.${DOMAIN_NAME?},{nginx,x,y,z}.apps.${DOMAIN_NAME?}}; do
  sudo sed -i -e "\$a${IP_LOADBALANCER?} ${SERVER?}" /etc/hosts
done
