#!/bin/bash
. ./check-environment-variables.sh

for SERVER in master-{1..1}; do
  if [[ "${SERVERS?}" =~ ${SERVER?} ]]; then
    multipass exec "${SERVER?}" -- sudo /shared/tools/install.sh
  fi
done
