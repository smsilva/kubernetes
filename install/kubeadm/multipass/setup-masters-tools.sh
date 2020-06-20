#!/bin/bash
. ./check-environment-variables.sh

for SERVER in ${SERVERS}; do
  if [[ ${SERVER} =~ ^master ]]; then
    multipass exec ${SERVER} -- sudo /shared/tools/install.sh
  fi
done
