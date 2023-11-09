# PostgreSQL k3d Deployment

## Prerequisites

- [k3d](https://k3d.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm](https://helm.sh/docs/intro/install/)

## Create k3d cluster

```bash
k3d cluster create \
  --api-port 6550 \
  --port "8888:80@loadbalancer" \
  --agents 2
```

## Install PostgreSQL

```bash
watch -n 3 'kubectl --namespace postgresql get statefulsets,deployments,pods,services,secrets'
```

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update bitnami

helm search repo bitnami/postgresql

helm install postgresql bitnami/postgresql \
  --create-namespace \
  --namespace postgresql \
  --wait \
  --values - <<EOF
auth:
  postgresPassword: pgpass
EOF
```

## Create a PostgreSQL Client POD

```bash
export POSTGRES_PASSWORD=$(kubectl get secret postgresql \
  --namespace postgresql \
  --output jsonpath="{.data.postgres-password}" \
  | base64 -d)

kubectl run postgresql-client \
  --namespace postgresql \
  --rm \
  --tty \
  --stdin \
  --restart Never \
  --env="PGPASSWORD=${POSTGRES_PASSWORD?}" \
  --image docker.io/bitnami/postgresql:16.0.0-debian-11-r15 \
  --command -- bash

psql \
  --host postgresql.postgresql.svc.cluster.local \
  --username postgres \
  --dbname postgres \
  --port 5432

# list databases
\l

# change database
\c postgres

# list tables
\dt

# list users
\du

# list roles
\du+

# list schemas
\dn

# list functions
\df

# list indexes
\di

# list sequences
\ds

# list views
\dv
```

# Install psql 16 on Ubuntu 22.04

```bash
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

sudo apt update

sudo apt install postgresql-client

psql --version
```
