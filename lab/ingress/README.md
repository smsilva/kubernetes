# Ingress

## Docker run NGINX

```bash
docker run \
  --rm \
  --detach \
  --publish 8080:80 \
  --name nginx \
  nginx:1.23.1

docker ps | egrep "CONTAINER|nginx"

curl -i http://localhost:8080

HTML_FILE="${PWD}/static/index.html"

if [ -e "${HTML_FILE?}" ]; then
  docker run \
    --rm \
    --detach \
    --volume "${HTML_FILE?}:/usr/share/nginx/html/index.html:ro" \
    --publish 8081:80 \
    --name nginx-customized \
    nginx:1.23.1
else
  echo "File \"${HTML_FILE}\" doesn't exists."
fi

docker ps | egrep "CONTAINER|nginx"

curl -i http://localhost:8081

docker kill nginx nginx-customized
```

## Docker run HTTPBIN

```bash
docker run \
  --rm \
  --detach \
  --publish 8080:80 \
  --name httpbin \
  kennethreitz/httpbin:latest

docker ps | egrep "CONTAINER|httpbin"

curl -i http://localhost:8080/get

docker kill httpbin
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
kubectl create namespace example

kubectl apply \
  --namespace example \
  --filename httpbin/deployment.yaml

kubectl apply \
  --namespace example \
  --filename httpbin/service.yaml

kubectl \
  --namespace example \
  wait deploy httpbin \
  --for=condition=Available \
  --timeout=360s
```

## Ingress for httpbin

```bash
kubectl apply \
  --namespace example \
  --filename httpbin/ingress.yaml
```

## Commands

```bash
nc -dv 127.0.0.1 80

ip -4 a

docker network ls

docker network inspect <docker-network-bridge-id>

curl \
  --include \
  --header 'host: xpto.example.com' \
  http://127.0.0.1:80/get
```

## Cleanup

```bash
kind delete cluster
```
