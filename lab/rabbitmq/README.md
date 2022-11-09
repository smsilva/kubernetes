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
watch -n 3 'kubectl -n wasp get deploy,pods -o wide'
```

## Logs

```bash
kubectl logs \
  --namespace wasp \
  --selector app=wasp-item-consumer \
  --follow
```
