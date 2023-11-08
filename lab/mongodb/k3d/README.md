# MongoDB Deployment into a k3d Cluster

## Prerequisites

- [k3d](https://k3d.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm](https://helm.sh/docs/intro/install/)

## Create a k3d cluster

```bash
mkdir -p /tmp/k3d/volumes/agents
mkdir -p /tmp/k3d/volumes/servers

k3d cluster create \
  --api-port 6550 \
  --port "8888:80@loadbalancer" \
  --agents 2 \
  --volume /tmp/k3d/volumes/agents:/data@agent:0,1 \
  --volume /tmp/k3d/volumes/servers:/data@server:0
```

## Install MongoDB

```bash
kubectl create namespace mongodb
```

```bash
export MONGODB_ROOT_PASSWORD=$(openssl rand -base64 32)

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
  mongodb-root-password: ${MONGODB_ROOT_PASSWORD?}
  mongodb-replica-set-key: $(openssl rand -base64 32)
  mongodb-metrics-password: $(openssl rand -base64 32)
  mongodb-passwords: "jubarte,cisne"
EOF
```

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update bitnami

helm search repo bitnami/mongodb

helm install mongodb bitnami/mongodb \
  --create-namespace \
  --namespace mongodb \
  --wait \
  --values - <<EOF
architecture: replicaset
auth:
  enabled: true
  existingSecret: "mongodb"
  replicaSetKey: "$(openssl rand -base64 32)"
  usernames:
    - silvios
    - paulos
  databases:
    - humpback
    - humpback
EOF
```

```bash
export MONGODB_DATABASE_NAME="admin"
export MONGODB_ROOT_USER="root"
export MONGODB_ROOT_PASSWORD=$(kubectl get secret mongodb \
  --namespace mongodb \
  --output jsonpath="{.data.mongodb-root-password}" \
  | base64 -d)

kubectl run mongodb-client \
  --namespace mongodb \
  --rm \
  --tty \
  --stdin \
  --restart='Never' \
  --env="MONGODB_DATABASE_NAME=${MONGODB_DATABASE_NAME?}" \
  --env="MONGODB_ROOT_USER=${MONGODB_ROOT_USER?}" \
  --env="MONGODB_ROOT_PASSWORD=${MONGODB_ROOT_PASSWORD?}" \
  --image docker.io/bitnami/mongodb:7.0.2-debian-11-r7 \
  --command -- bash

mongosh ${MONGODB_DATABASE_NAME?} \
  --host "mongodb-0.mongodb-headless.mongodb.svc.cluster.local:27017,mongodb-1.mongodb-headless.mongodb.svc.cluster.local:27017" \
  --authenticationDatabase admin \
  --username ${MONGODB_ROOT_USER?} \
  --password ${MONGODB_ROOT_PASSWORD?}

mongosh humpback \
  --host "mongodb-0.mongodb-headless.mongodb.svc.cluster.local:27017,mongodb-1.mongodb-headless.mongodb.svc.cluster.local:27017" \
  --username silvios \
  --password jubarte
```

## Test Persistent Volume Claim creation

```bash
kubectl create namespace demo
```

```bash
watch -n 3 'kubectl --namespace demo get pv,pvc,pods'
```

```bash
kubectl apply \
  --namespace demo \
  --filename - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb
spec:
  accessModes:
    - ReadWriteOnce 

  resources:
    requests:
      storage: 100Mi
EOF
```

### Create a Pod to Test the Persistent Volume Claim

```bash
kubectl apply \
  --namespace demo \
  --filename - <<EOF
---
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu
spec:
  containers:
    - name: ubuntu
      image: ubuntu:22.04

      command:
        - sleep
        - infinity

      volumeMounts:
        - name: mongodb
          mountPath: /data/db

  volumes:
    - name: mongodb
      persistentVolumeClaim:
        claimName: mongodb
EOF

kubectl --namespace demo exec ubuntu -- find /data/

kubectl --namespace demo exec ubuntu -- /bin/bash -c 'echo "Hello!" > /data/db/hello.txt'

kubectl --namespace demo exec ubuntu -- find /data/

kubectl --namespace demo exec ubuntu -- cat /data/db/hello.txt

kubectl delete namespace demo
```

## Cleanup

```bash
k3d cluster delete
```
