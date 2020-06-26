#!/bin/bash
for SERVER in ${SERVERS}; do
  ./update.sh ${SERVER}
  echo "${SERVER} updated"
done
