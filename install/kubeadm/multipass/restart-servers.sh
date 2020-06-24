#!/bin/bash
. ./check-environment-variables.sh

multipass restart dns
multipass exec dns -- sudo systemctl status bind9

for SERVER in ${SERVERS}; do
  if [[ ! ${SERVER} =~ ^dns ]]; then 
    multipass exec ${SERVER} -- sudo reboot
  fi
done

multipass exec loadbalancer -- sudo systemctl status haproxy
