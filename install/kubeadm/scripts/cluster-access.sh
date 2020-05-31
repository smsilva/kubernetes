#!/bin/bash

# Creation of a Private Key and a Certificate Signing Request (CSR)
openssl genrsa -out dave.key 4096

# 
cat <<EOF > csr.cnf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
CN = dave
O = dev

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
EOF

openssl req \
  -config ./csr.cnf \
  -new -key dave.key \
  -nodes -out dave.csr

cat <<EOF > csr.yaml
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: mycsr
spec:
  groups:
  - system:authenticated
  request: \${BASE64_CSR}
  usages:
  - digital signature
  - key encipherment
  - server auth
  - client auth
EOF

# Encoding the .csr file in base64
export BASE64_CSR=$(cat ./dave.csr | base64 | tr -d '\n')

echo ${BASE64_CSR}

# Substitution of the BASE64_CSR env variable and creation of the CertificateSigninRequest resource
cat csr.yaml | envsubst | kubectl apply -f -

# Check
k get csr

# Approve
kubectl certificate approve mycsr

# Extract Certificate
kubectl get csr mycsr -o jsonpath='{.status.certificate}' \
  | base64 --decode > dave.crt

# Show Certificate Information
openssl x509 -in ./dave.crt -noout -text

# Create a Namespace
kubectl create ns development

k config set-context --current --namespace=development

cat <<EOF > role.yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: development
  name: dev
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["create", "get", "update", "list", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "get", "update", "list", "delete"]
EOF

kubectl apply -f role.yaml

cat <<EOF > role-binding.yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: dev
  namespace: development
subjects:
- kind: User
  name: dave
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: dev
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f role-binding.yaml

cat <<EOF > kubeconfig.tpl
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: \${CERTIFICATE_AUTHORITY_DATA}
    server: \${CLUSTER_ENDPOINT}
  name: \${CLUSTER_NAME}
users:
- name: \${USER}
  user:
    client-certificate-data: \${CLIENT_CERTIFICATE_DATA}
contexts:
- context:
    cluster: \${CLUSTER_NAME}
    user: dave
  name: \${USER}-\${CLUSTER_NAME}
current-context: \${USER}-\${CLUSTER_NAME}
EOF

# User identifier
export USER="dave"
export CLUSTER_NAME=$(kubectl config current-context | awk -F "@" '{ print $2 }')
export CLIENT_CERTIFICATE_DATA=$(kubectl get csr mycsr -o jsonpath='{.status.certificate}')

# Base Command to Extract "server" and "cluster.certificate-authority-data"
BASE_COMMAND="kubectl config view -o jsonpath='{.clusters[?(@.name==\"%s\")].cluster.%s}' --raw"

# Cluster Certificate Authority and API Server endpoint
COMMAND=$(printf "${BASE_COMMAND}" "${CLUSTER_NAME}" "certificate-authority-data") && export CERTIFICATE_AUTHORITY_DATA=$(${COMMAND} | tr -d "'")
COMMAND=$(printf "${BASE_COMMAND}" "${CLUSTER_NAME}" "server") && export CLUSTER_ENDPOINT=$(${COMMAND} | tr -d "'")

echo "USER........................: ${USER}" && \
echo "CLUSTER_NAME................: ${CLUSTER_NAME}" && \
echo "CLIENT_CERTIFICATE_DATA.....: ${#CLIENT_CERTIFICATE_DATA} (length)" && \
echo "CERTIFICATE_AUTHORITY_DATA..: ${#CERTIFICATE_AUTHORITY_DATA} (length)" && \
echo "CLUSTER_ENDPOINT............: ${CLUSTER_ENDPOINT}"

# View Template File
cat kubeconfig.tpl | yq r -

# Only show a template with values
cat kubeconfig.tpl | envsubst | yq r -

# Save it to a file
cat kubeconfig.tpl | envsubst > dave_kubeconfig

# Dave should save the file as:
${HOME}/.kube/config

# And add his private key to it:
kubectl config set-credentials dave \
  --client-key=$PWD/dave.key \
  --embed-certs=true

# Try to get Nodes
k get nodes

mkdir dave && cd dave

cat <<EOF > www.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: www
  namespace: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: www
  template:
    metadata:
      labels:
        app: www
    spec:
      containers:
      - name: nginx
        image: nginx:1.18
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: www
  namespace: development
spec:
  selector:
    app: vote
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
EOF

