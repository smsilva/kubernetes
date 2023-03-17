# Deployments

## Docker

```bash
docker run \
  --detach \
  --publish 8000:80 \
  --name nginx-blue \
  silviosilva/nginx-blue:1.23.3-alpine

docker run \
  --detach \
  --publish 8001:80 \
  --name nginx-green \
  silviosilva/nginx-green:1.23.3-alpine

docker ps

curl -i localhost:8000/data.json

curl -i localhost:8001/data.json

docker kill nginx-blue nginx-green
```

## k3s Cluster

```bash
k3d cluster create --agents 2

kubectl get nodes -o wide
```

## Imperative

```bash
# Create Namespace
kubectl create namespace demo

kubectl config get-contexts

kubectl config set-context --current --namespace demo

kubectl config get-contexts

# Watch for Resources
watch -n 3 'kubectl -n demo get deploy,replicasets,pods,service -o wide'

# Create Deployment
kubectl create deployment app-example \
  --namespace demo \
  --image silviosilva/nginx-blue:1.23.3-alpine

# Create a POD to test
kubectl run \
  -it \
  --namespace demo \
  --rm \
  --image silviosilva/utils utils -- /bin/sh

# Create a Service
kubectl \
  --namespace demo \
  expose deploy app-example \
  --port 8000 \
  --target-port 80

# Scale Deployment
kubectl \
  --namespace demo \
  scale deploy app-example \
  --replicas 3

# Delete Deployment
kubectl delete deployment app-example \
  --namespace demo

# Retrieve the Deployment yaml file
kubectl create deployment app-example \
  --namespace demo \
  --image silviosilva/nginx-blue:1.23.3-alpine \
  --dry-run=client \
  --output yaml \
| kubectl neat \
| tee deploy.yaml

kubectl apply -f deploy.yaml \
  --namespace demo

# Change Deployment Image
kubectl \
  --namespace demo \
  set image deployment/app-example application=silviosilva/nginx-green:1.23.3-alpine

kubectl rollout undo deployment app-example
  
kubectl \
  --namespace demo \
  set image deployment/app-example application=silviosilva/nginx-blue:1.23.3-alpine

kubectl \
  --namespace demo \
  get endpoints app-example
```
