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
  --agents 2
```

## Install MongoDB

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
  mongodb-passwords: "jubarte,cisne"
EOF
```

```bash
watch -n 3 'kubectl --namespace mongodb get statefulsets,deployments,pods,services,secrets'
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
architecture: replicaset # "standalone" or "replicaset"
auth:
  enabled: true
  existingSecret: mongodb
  usernames:
    - silvios
    - paulos
  databases:
    - humpback
    - humpback
EOF
```

### Create a Mongo Shell Pod

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
  --restart Never \
  --env="MONGODB_DATABASE_NAME=${MONGODB_DATABASE_NAME?}" \
  --env="MONGODB_ROOT_USER=${MONGODB_ROOT_USER?}" \
  --env="MONGODB_ROOT_PASSWORD=${MONGODB_ROOT_PASSWORD?}" \
  --image docker.io/bitnami/mongodb:7.0.3-debian-11-r1 \
  --command -- bash
```

### Connect to the MongoDB Server (archicteture = standalone)

```bash
mongosh ${MONGODB_DATABASE_NAME?} \
  --host "mongodb.mongodb.svc.cluster.local:27017" \
  --username ${MONGODB_ROOT_USER?} \
  --password ${MONGODB_ROOT_PASSWORD?}

mongosh humpback \
  --host "mongodb.mongodb.svc.cluster.local:27017" \
  --username silvios \
  --password jubarte
```

### Connect to the MongoDB Server (archicteture = replicaset)

```bash
mongosh ${MONGODB_DATABASE_NAME?} \
  --host "mongodb-0.mongodb-headless.mongodb.svc.cluster.local:27017,mongodb-1.mongodb-headless.mongodb.svc.cluster.local:27017" \
  --username ${MONGODB_ROOT_USER?} \
  --password ${MONGODB_ROOT_PASSWORD?}

mongosh ${MONGODB_DATABASE_NAME?} \
  --host "mongodb-headless.mongodb.svc.cluster.local:27017" \
  --username ${MONGODB_ROOT_USER?} \
  --password ${MONGODB_ROOT_PASSWORD?}

mongosh humpback \
  --host "mongodb-headless.mongodb:27017" \
  --username silvios \
  --password jubarte
```

### Connect from outside the cluster

```bash
kubectl apply \
  --namespace mongodb \
  --filename - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb-nodeport
spec:
  type: NodePort

  selector:
    app.kubernetes.io/component: mongodb
    app.kubernetes.io/instance: mongodb
    app.kubernetes.io/name: mongodb

  ports:
    - name: tcp-mongodb
      port: 27017
      targetPort: 27017
      nodePort: 30001
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mongodb
spec:
  ingressClassName: traefik
  rules:
    - host: mongodb.example.com
      http:
        paths:
          - path: /
            pathType: Exact
            backend:
              service:
                name: mongodb-nodeport
                port:
                  number: 27017           
EOF
```

```bash
nc -dv localhost 27017
```

```bash
echo "127.0.0.1   mongodb.example.com" | sudo tee -a /etc/hosts
```

```bash
mongosh humpback \
  --host "mongodb.example.com:27017" \
  --username silvios \
  --password jubarte
```

## Cleanup

```bash
k3d cluster delete
```
