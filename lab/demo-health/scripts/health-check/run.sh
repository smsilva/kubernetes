#!/bin/sh
INTERVAL=$1
while true; do
  NOW=$(date "+%Y-%m-%d %H:%M:%S")
  curl -s http://localhost:8080/actuator/health > /dev/null
  echo "${NOW} health-check-result: $?"
  sleep ${INTERVAL:-3}
done
