#!/bin/bash
. ./check-environment-variables.sh

for SERVER in ${SERVERS}; do
  if [[ ${SERVER} =~ ^master|^worker ]]; then
    multipass exec ${SERVER} -- sudo /shared/containerd/install.sh > /dev/null
  fi
done
