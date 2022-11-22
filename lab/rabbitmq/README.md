# RabbitMQ Consumer

## Create Kind Cluster

```bash
kind create cluster
```

## Deploy wasp-consumer

```bash
./deploy
```

## Watch for Resources

```bash
watch -n 3 'kubectl get deploy,pods \
  --namespace wasp \
  --output wide'
```

## Logs

```bash
kubectl logs \
  --namespace wasp \
  --selector app=wasp-item-consumer \
  --follow
```

# RabbitMQ Install Helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm search repo bitnami/rabbitmq

helm install rabbitmq bitnami/rabbitmq \
  --create-namespace \
  --namespace rabbitmq \
  --wait
```
