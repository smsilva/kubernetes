#!/bin/bash
. ./check-environment-variables.sh

for SERVER in ${SERVERS?}; do
  multipass exec ${SERVER?} -- sudo /shared/update-system-config.sh
done
