# Ingress

## Docker run nginx

```bash
docker run \
  --rm \
  --tty \
  --interactive \
  --volume "${PWD}/site/index.html:/usr/share/nginx/html/index.html" \
  --publish 8080:80 \
  nginx
```

## Watch resouces

```bash
watch -n 3 ./follow
```

## Create a Kind Cluster

```bash
kind/creation
```

## NGINX Ingress Controller Install

```bash
nginx/install
```

## Deploy httpbin

Execute it from a new terminal window:

```bash
kubectl create namespace apps

kubectl apply \
  --namespace apps \
  --filename httpbin/deployment.yaml

kubectl apply \
  --namespace apps \
  --filename httpbin/service.yaml

kubectl \
  --namespace apps \
  wait deploy httpbin \
  --for=condition=Available \
  --timeout=360s
```

## Ingress for httpbin

```bash
kubectl apply \
  --namespace apps \
  --filename httpbin/ingress.yaml
```

## Commands

```bash
nc -dv 127.0.0.1 80
nc -dv 127.0.0.1 32080

ip -4 a

docker network ls

docker network inspect <docker-network-bridge-id>

curl \
  --include \
  --header 'host: xpto.example.com' \
  http://127.0.0.1:80/get

curl \
  --include \
  --header 'host: xpto.example.com' \
  http://127.0.0.1:32080/get
```

## Cleanup

```bash
kind delete cluster
```
