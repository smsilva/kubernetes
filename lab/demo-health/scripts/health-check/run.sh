#!/bin/sh
echo "PORT........: ${PORT}"
echo "ENDPOINT....: ${ENDPOINT}"
echo "INTERVAL....: ${INTERVAL}"

while true; do
  NOW=$(date "+%Y-%m-%d %H:%M:%S")
  curl -s http://localhost:${PORT:-8080}${ENDPOINT:-"/actuator/health"} > /dev/null
  echo "${NOW} result: $?"
  sleep ${INTERVAL:-3}
done
