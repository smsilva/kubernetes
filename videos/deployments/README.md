# Deployments

## Docker

```bash
docker run \
  --rm \
  --detach \
  --publish 8000:80 \
  --name httpbin \
  kennethreitz/httpbin

docker run \
  --rm \
  --detach \
  --publish 8001:80 \
  --name nginx \
  nginx

docker ps

curl -i localhost:8000/get
curl -i localhost:8001

docker kill nginx httpbin
```

## k3s Cluster

```bash
k3d cluster create --agents 3

kubectl get nodes -o wide
```

## Imperative

```bash
# Create Namespace
kubectl create namespace demo

kubectl config get-contexts

kubectl config set-context --current --namespace demo

# Watch for Resources
watch -n 3 'kubectl -n demo get deploy,replicasets,pods,service -o wide'

# Create Deployment
kubectl create deployment httpbin \
  --namespace demo \
  --image kennethreitz/httpbin \
  --replicas 1

# Create a POD to test
kubectl run \
  -it \
  --namespace demo \
  --rm \
  --image silviosilva/utils utils -- /bin/sh

# Create a Service
kubectl \
  --namespace demo \
  expose deploy httpbin \
  --port 8000 \
  --target-port 80

# Scale Deployment
kubectl \
  --namespace demo \
  scale deploy httpbin \
  --replicas 3

# Change Deployment Image
kubectl \
  --namespace demo \
  set image deployment/httpbin httpbin=nginx:latest

kubectl rollout undo deployment httpbin
  
kubectl \
  --namespace demo \
  set image deployment/httpbin httpbin=kennethreitz/httpbin

kubectl \
  --namespace demo \
  get endpoints httpbin
```
