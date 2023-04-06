# Keda

## Deploy RabbitMQ

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm search repo bitnami/rabbitmq

helm install \
  --namespace rabbitmq \
  --create-namespace \
  rabbitmq bitnami/rabbitmq \
  --wait

kubectl port-forward svc/rabbitmq 15672:15672 \
  --namespace rabbitmq

export RABBITMQ_USERNAME="user"
export RABBITMQ_PASSWORD=$(kubectl get secret rabbitmq \
  --namespace rabbitmq \
  --output jsonpath="{.data.rabbitmq-password}" \
  | base64 -d)

echo "Username.: ${RABBITMQ_USERNAME}"
echo "Password.: ${RABBITMQ_PASSWORD}"
echo "URL......: http://127.0.0.1:15672/"
```

### Create a Queue called 'events'

```bash
curl \
  --include \
  --user ${RABBITMQ_USERNAME?}:${RABBITMQ_PASSWORD?} \
  --request PUT \
  http://localhost:15672/api/queues/%2F/events \
  --header "content-type:application/json" \
  --data '{"auto_delete":false,"durable":true,"arguments":{}}'

curl \
  --silent \
  --user ${RABBITMQ_USERNAME?}:${RABBITMQ_PASSWORD?} \
  http://localhost:15672/api/queues \
| jq .

curl \
  --include \
  --user ${RABBITMQ_USERNAME?}:${RABBITMQ_PASSWORD?} \
  --header "content-type:application/json" \
  --request POST \
  http://localhost:15672/api/bindings/%2f/e/amq.direct/q/events \
  --data '{"routing_key":"events", "arguments":{}}'
```

### Post a Message

```bash
curl \
  --silent \
  --user ${RABBITMQ_USERNAME?}:${RABBITMQ_PASSWORD?} \
  --header "content-type:application/json" \
  --request POST \
  http://localhost:15672/api/exchanges/%2f/amq.direct/publish \
  --data '{"properties":{"delivery_mode":2},"routing_key":"events","payload":"my body","payload_encoding":"string"}'

curl \
  --silent \
  --user ${RABBITMQ_USERNAME?}:${RABBITMQ_PASSWORD?} \
  http://localhost:15672/api/queues/%2f/events \
| jq .messages_ready
```

## Deploy Consumer

```bash
cat <<EOF > /tmp/keda.conf
export RABBITMQ_HOST="rabbitmq.rabbitmq.svc.cluster.local"
export RABBITMQ_PORT="5672"
export RABBITMQ_VIRTUAL_HOST="/"
export RABBITMQ_USERNAME="${RABBITMQ_USERNAME-silvios}"
export RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD-A password here}"
export RABBITMQ_PASSWORD_URL_ENCODED=\$(
  printf %s "\${RABBITMQ_PASSWORD?}" \
  | jq -sRr @uri
)
export RABBITMQ_QUEUE_NAME_MAIN="events"
export RABBITMQ_AMQP_URL="amqp://\${RABBITMQ_USERNAME?}:\${RABBITMQ_PASSWORD_URL_ENCODED?}@\${RABBITMQ_HOST?}:\${RABBITMQ_PORT?}/\${RABBITMQ_VIRTUAL_HOST?}"

echo "RABBITMQ_HOST.................: \${RABBITMQ_HOST}"
echo "RABBITMQ_PORT.................: \${RABBITMQ_PORT}"
echo "RABBITMQ_VIRTUAL_HOST.........: \${RABBITMQ_VIRTUAL_HOST}"
echo "RABBITMQ_USERNAME.............: \${RABBITMQ_USERNAME}"
echo "RABBITMQ_PASSWORD.............: \${RABBITMQ_PASSWORD:0:6}"
echo "RABBITMQ_PASSWORD_URL_ENCODED.: \${RABBITMQ_PASSWORD_URL_ENCODED:0:6}"
echo "RABBITMQ_QUEUE_NAME_MAIN......: \${RABBITMQ_QUEUE_NAME_MAIN}"
EOF

source /tmp/keda.conf

kubectl create namespace wasp

kubectl apply \
  --namespace wasp \
  --filename - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: wasp-item-consumer-rabbitmq
type: Opaque
stringData:
  RABBITMQ_HOST:            "${RABBITMQ_HOST?}"
  RABBITMQ_PORT:            "${RABBITMQ_PORT?}"
  RABBITMQ_VIRTUAL_HOST:    "${RABBITMQ_VIRTUAL_HOST?}"
  RABBITMQ_USERNAME:        "${RABBITMQ_USERNAME?}"
  RABBITMQ_PASSWORD:        "${RABBITMQ_PASSWORD?}"
  RABBITMQ_QUEUE_NAME_MAIN: "${RABBITMQ_QUEUE_NAME_MAIN?}"
  RABBITMQ_AMQP_URL:        "${RABBITMQ_AMQP_URL?}"
EOF

kubectl apply \
  --namespace wasp \
  --filename "./deploy/consumer.yaml" && \
kubectl wait deployment \
  --namespace wasp \
  --for condition=Available \
  --selector app=wasp-item-consumer && \
kubectl logs \
  --namespace wasp \
  --selector app=wasp-item-consumer \
  --follow

kubectl scale deployment wasp-item-consumer \
  --namespace wasp \
  --replicas 0

watch -n 3 'kubectl -n wasp get TriggerAuthentication,ScaledObject,deploy,hpa,pods'
```

## Install Keda

```bash
helm repo add kedacore https://kedacore.github.io/charts

helm repo update kedacore

helm search repo kedacore/keda

helm install \
  --create-namespace \
  --namespace keda \
  keda kedacore/keda \
  --wait
```

## Logs

```bash
watch -n 3 'kubectl -n wasp logs -l app=wasp-item-consumer --tail 3'
```

## Create Keda Resources

```bash
kubectl apply \
  --namespace wasp \
  --filename "deploy/keda-resources.yaml"
```
