#!/bin/bash
. ./check-environment-variables.sh

multipass restart dns

for SERVER in ${SERVERS}; do
  if [[ ! ${SERVER} =~ ^dns ]]; then
    multipass restart ${SERVER}
  fi
done
