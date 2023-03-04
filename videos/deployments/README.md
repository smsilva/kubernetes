# Deployments

## Kind Cluster

```bash
kind get clusters

cat <<EOF > /tmp/cluster.yaml
---
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
EOF

cat /tmp/cluster.yaml

kind create cluster \
  --config "/tmp/cluster.yaml"

kubectl get nodes
```

## Docker run

```bash
docker run \
  --rm \
  --detach \
  --publish 8080:80 \
  --name httpbin \
  docker.io/kennethreitz/httpbin
```

## Imperative

```bash
# Create Deployment
kubectl create deployment \
--image docker.io/kennethreitz \
httpbin my-httpbin-app

# Create a POD to test
kubectl run \
  -it \
  --rm \
  --image silviosilva/utils utils -- /bin/sh

# Create a POD
```
