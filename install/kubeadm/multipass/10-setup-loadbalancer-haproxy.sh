#!/bin/bash
. ./check-environment-variables.sh

./wait-for-running.sh loadbalancer

# HAProxy
# https://www.haproxy.com/blog/the-four-essential-sections-of-an-haproxy-configuration/
HAPROXY_CONFIG_FILE="shared/loadbalancer/haproxy.cfg"

cat templates/loadbalancer/haproxy.cfg | envsubst > "${HAPROXY_CONFIG_FILE?}"

awk '/#.*:.*/ { print $1 }' < "${HAPROXY_CONFIG_FILE?}" | while read KEY; do
  PORT=$(awk -F ":" '{ print $2 }' <<< "${KEY?}")
  LINE_NUMBER=$(sed -n "/${KEY?}/=" "${HAPROXY_CONFIG_FILE?}")

  ./masters.sh | while read SERVER; do
    LINE="server ${SERVER?} ${SERVER?}.${DOMAIN_NAME?}:${PORT?}"
    sed -i "${LINE_NUMBER?}i\    ${LINE?}" "${HAPROXY_CONFIG_FILE?}"
    LINE_NUMBER=$((${LINE_NUMBER?} + 1))
  done

  sed -i "/${KEY?}/ d" "${HAPROXY_CONFIG_FILE?}"
done

multipass exec loadbalancer -- sudo /shared/loadbalancer/install.sh
