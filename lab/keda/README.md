# Keda

## Install using Helm Chart

```bash
./install
```

## Create Secret with AMQP Connection URL

```bash
./create-secret
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
