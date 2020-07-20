#!/bin/sh
INTERVAL=$1
PORT=$2
ENDPOINT=$3
while true; do
  NOW=$(date "+%Y-%m-%d %H:%M:%S")
  curl -s http://localhost:${PORT:-8080}/${ENDPOINT:-"/actuator/health"} > /dev/null
  echo "${NOW} health-check-result: $?"
  sleep ${INTERVAL:-3}
done
