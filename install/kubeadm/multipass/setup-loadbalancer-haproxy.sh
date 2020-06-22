#!/bin/bash
. ./check-environment-variables.sh

# HAProxy
# https://www.haproxy.com/blog/the-four-essential-sections-of-an-haproxy-configuration/
FILE="shared/loadbalancer/haproxy.cfg"

cat templates/loadbalancer/haproxy.cfg | envsubst > "${FILE}"

awk '/#.*:.*/ { print $1 }' < "${FILE}" | while read KEY; do
  PORT=$(awk -F ":" '{ print $2 }' <<< "${KEY}")
  LINE_NUMBER=$(sed -n "/${KEY}/=" "${FILE}")

  ./masters.sh | while read SERVER; do
    LINE="server ${SERVER} ${SERVER}.${DOMAIN_NAME}:${PORT}"
    sed -i "${LINE_NUMBER}i\    ${LINE}" "${FILE}"
    LINE_NUMBER=$((${LINE_NUMBER} + 1))
  done

  sed -i "/${KEY}/ d" "${FILE}"
done

multipass exec loadbalancer -- sudo /shared/loadbalancer/install.sh
