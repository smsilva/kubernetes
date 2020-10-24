#!/bin/bash
REDIS_INSECURE_PASSWORD="GMyIurI2LqvSN/wKsklBUY0KYPUbfiv1maVc6OGhGIikH7Q/7PDlEeF1fZa0fydp+NK0MEuH0oS4mNqx"

for CONTAINER_NAME in redis-{01,02}; do
  CONTAINER_ID=$(docker ps -f name=${CONTAINER_NAME} | sed 1d | awk '{ print $1 }')

  if ! [ -z "${CONTAINER_ID}" ]; then
    docker kill ${CONTAINER_ID}
  fi
done

docker system prune -f

REDIS_LOCAL_PORT=6379

for CONTAINER_NAME in redis-{01,02}; do
  docker run \
    --name "${CONTAINER_NAME}" \
    -v $PWD/config/redis-example.conf:/usr/local/etc/redis/redis.conf \
    -p ${REDIS_LOCAL_PORT}:6379 \
    --detach \
    redis:6.0.8 redis-server /usr/local/etc/redis/redis.conf

  REDIS_LOCAL_PORT=$((REDIS_LOCAL_PORT + 1))
done

echo ""
echo "Try this:"
echo ""
echo "  sudo apt update && sudo apt install redis-tools --yes"
echo "  redis-cli -h 127.0.0.1 -p 6379 -a ${REDIS_INSECURE_PASSWORD}"
echo "  redis-cli -h 127.0.0.1 -p 6380 -a ${REDIS_INSECURE_PASSWORD}"
echo ""
