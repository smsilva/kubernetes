#!/bin/bash
. ./check-environment-variables.sh

for SERVER in ${SERVERS}; do
  multipass exec ${SERVER} -- sudo apt-get update &> /dev/null
  multipass exec ${SERVER} -- sudo apt-get upgrade --yes &> /dev/null
  echo "[${SERVER}] System update done."
done
