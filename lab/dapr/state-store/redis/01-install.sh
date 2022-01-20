#!/bin/bash

# Create a Redis store
# https://docs.dapr.io/getting-started/configure-state-pubsub/#create-a-redis-store

helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update

helm install redis bitnami/redis --wait

export REDIS_PASSWORD=$(kubectl get secret --namespace default redis -o jsonpath="{.data.redis-password}" | base64 --decode)

kubectl run \
  redis-client \
  --namespace default \
  --restart='Never' \
  --env REDIS_PASSWORD=${REDIS_PASSWORD?} \
  --image docker.io/bitnami/redis:6.2.3-debian-10-r22 \
  --command -- sleep infinity

kubectl wait \
  --for condition=Ready \
  pod redis-client

kubectl exec \
  --tty \
  --stdin \
  redis-client \
  --namespace default -- redis-cli -h redis-master -a ${REDIS_PASSWORD?}
