# Keda

## Install using Helm Chart

```bash
helm repo add kedacore https://kedacore.github.io/charts &> /dev/null

helm repo update kedacore &> /dev/null

helm search repo kedacore/keda

helm upgrade \
  --install \
  --create-namespace \
  --namespace keda \
  keda kedacore/keda \
  --wait
```

## Create Secret with AMQP Connection URL

```bash
AMQP_CONNECTION_URL="amqp://${RABBITMQ_USERNAME?}:${RABBITMQ_PASSWORD?}@${RABBITMQ_HOST?}:${RABBITMQ_PORT?}/${RABBITMQ_VIRTUAL_HOST?}"

kubectl \
  --namespace wasp \
  apply -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
   name: keda-rabbitmq-secret
stringData:
  host: "${AMQP_CONNECTION_URL}"
EOF
```

## Watch for Resources

```bash
watch -n 3 'kubectl -n wasp get TriggerAuthentication,ScaledObject,deploy,pods -o wide'
```

## Create Keda Resources

```bash
kubectl -n wasp apply -f trigger-authentication.yaml
kubectl -n wasp apply -f scaled-object.yaml
```

## Logs

```bash
watch -n 3 'kubectl -n wasp logs -l app=wasp-item-consumer --tail 3'
```
