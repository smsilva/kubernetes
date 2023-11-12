# MongoDB Deployment into a k3d Cluster

## Prerequisites

- [k3d](https://k3d.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm](https://helm.sh/docs/intro/install/)

## Create a k3d cluster

```bash
k3d cluster create \
  --api-port 6550 \
  --port "8080:80@loadbalancer" \
  --port "27017:30001@agent:0" \
  --port "27018:30002@agent:0" \
  --agents 2
```

## MongoDB Preparation

```bash
kubectl create namespace mongodb
```

```bash
kubectl apply \
  --namespace mongodb \
  --filename - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: mongodb
type: Opaque
stringData:
  mongodb-root-password: $(openssl rand -base64 32)
  mongodb-replica-set-key: $(openssl rand -base64 32)
  mongodb-metrics-password: $(openssl rand -base64 32)
  mongodb-passwords: "local,jubarte"
EOF
```

```bash
export MONGODB_ROOT_USER="root"
export MONGODB_ROOT_PASSWORD=$(kubectl get secret mongodb \
  --namespace mongodb \
  --output jsonpath="{.data.mongodb-root-password}" \
  | base64 -d)

kubectl run mongodb-client \
  --namespace mongodb \
  --restart Never \
  --env="MONGODB_ROOT_USER=${MONGODB_ROOT_USER?}" \
  --env="MONGODB_ROOT_PASSWORD=${MONGODB_ROOT_PASSWORD?}" \
  --image docker.io/bitnami/mongodb:7.0.3-debian-11-r1 \
  --command -- sleep infinity
```

```bash
watch -n 3 'kubectl --namespace mongodb get statefulsets,deployments,pods,services,secrets'
```

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update bitnami

helm search repo bitnami/mongodb
```

## Install MongoDB: archicteture = standalone

```bash
helm install mongodb bitnami/mongodb \
  --create-namespace \
  --namespace mongodb \
  --wait \
  --values - <<EOF
architecture: standalone
service:
  type: NodePort
  nodePorts:
    mongodb: "30001"
auth:
  enabled: true
  existingSecret: mongodb
  usernames:
    - developer
    - silvios
  databases:
    - dev
    - dev
EOF
```

### Connect to the MongoDB Server from inside the cluster

```bash
kubectl exec mongodb-client \
  --namespace mongodb \
  --tty \
  --stdin -- bash
```

```bash
mongosh \
  --host "mongodb.mongodb.svc.cluster.local:27017" \
  --username ${MONGODB_ROOT_USER?} \
  --password ${MONGODB_ROOT_PASSWORD?}
```

```bash
mongosh dev \
  --host "mongodb.mongodb.svc.cluster.local:27017" \
  --username developer \
  --password local
```

```bash
mongosh dev \
  --host "mongodb.mongodb.svc.cluster.local:27017" \
  --username silvios \
  --password jubarte
```

### Connect from outside the cluster

```bash
mongosh dev \
  --host "localhost:27017" \
  --username developer \
  --password local
```

```bash
mongosh dev \
  --host "localhost:27017" \
  --username silvios \
  --password jubarte
```

```bash
show collections
db.movies.insertMany([{"name":"The Matrix"},{"name":"Avatar"}])
db.movies.find()
```

## Install MongoDB: archicteture = replicaset

```bash
helm install mongodb bitnami/mongodb \
  --create-namespace \
  --namespace mongodb \
  --wait \
  --values - <<EOF
architecture: replicaset
externalAccess:
  enabled: true
  service:
    type: NodePort
    nodePorts:
      - 30001
      - 30002
auth:
  enabled: true
  existingSecret: mongodb
  usernames:
    - developer
    - silvios
  databases:
    - dev
    - dev
EOF
```

### Connect to the MongoDB Server: archicteture = replicaset

```bash
kubectl exec mongodb-client \
  --namespace mongodb \
  --tty \
  --stdin -- bash
```

```bash
mongosh \
  --host "mongodb-0.mongodb-headless.mongodb.svc.cluster.local:27017,mongodb-1.mongodb-headless.mongodb.svc.cluster.local:27017" \
  --username ${MONGODB_ROOT_USER?} \
  --password ${MONGODB_ROOT_PASSWORD?}
```

```bash
mongosh dev \
  --host "mongodb-0.mongodb-headless.mongodb.svc.cluster.local:27017,mongodb-1.mongodb-headless.mongodb.svc.cluster.local:27017" \
  --username silvios \
  --password jubarte
```

```bash
show collections
db.movies.insertMany([{"name":"The Matrix"},{"name":"Avatar"}])
db.movies.find()
```

## Cleanup

```bash
k3d cluster delete
```
