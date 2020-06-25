#!/bin/bash
. ./check-environment-variables.sh

./list.sh | while read line; do
  SERVER_NAME=$(awk '{ print $1 }' <<< "${line}" | sed 's/-/_/g')
  SERVER_IP=$(awk '{ print $2 }' <<< "${line}")
  SERVER_IP_LAST_OCTET=${SERVER_IP##*.}

  echo "export IP_${SERVER_NAME^^}=${SERVER_IP}"
  echo "export IP_LAST_OCTET_${SERVER_NAME^^}=${SERVER_IP_LAST_OCTET}"
done
