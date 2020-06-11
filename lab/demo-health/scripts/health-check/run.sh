#!/bin/sh
URL=http://localhost:${PORT:-8080}${ENDPOINT:-"/actuator/health"}

echo "PORT........: ${PORT}"
echo "ENDPOINT....: ${ENDPOINT}"
echo "INTERVAL....: ${INTERVAL}"
echo "URL.........: ${URL}"

while true; do
  NOW=$(date "+%Y-%m-%d %H:%M:%S")

  curl -s ${URL} > /dev/null

  echo "${NOW} result: $?"

  sleep ${INTERVAL:-3}
done
