#!/bin/bash
echo ""
echo "Updating Servers"
echo ""

for SERVER in ${SERVERS}; do
  ./update.sh ${SERVER}

  echo "${SERVER} updated"
done

echo ""
