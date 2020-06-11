#!/bin/bash
. ./check-environment-variables.sh

for SERVER in master-{1..1}; do
  if [[ "${SERVERS}" =~ ${SERVER} ]]; then
    multipass exec "master-1" -- sudo /shared/tools/install.sh
  fi
done
