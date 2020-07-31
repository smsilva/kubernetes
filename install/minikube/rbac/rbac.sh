#!/bin/bash

# Create and Access a user empty directory
GIT_BASE_DIR="${HOME}/pessoal/git"
WORK_DIR="${GIT_BASE_DIR}/kubernetes/install/minikube/rbac/dave"
mkdir -p "${WORK_DIR}" && cd "${WORK_DIR}"

# Create a Minikube Cluster
export MINIKUBE_IN_STYLE=false && \
minikube start \
  --kubernetes-version v1.17.7 \
  --driver=docker \
  --network-plugin=cni

kubectl config use-context minikube

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml  

kubectl config get-contexts minikube

# Create a Namespace
kubectl create ns development

# Set the Default Namespace for Minikube context
kubectl config set-context minikube --namespace=development

kubectl apply -f ../rules/

# Create an Multipass Instance that will be used to simulate the user Dave Machine
INSTANCE_NAME="hal-9000"
CLOUD_INIT_FILE="${INSTANCE_NAME}-cloud-init.yaml"

cat <<EOF > "${CLOUD_INIT_FILE}"
#cloud-config
hostname: hal-9000

write_files:
- encoding: b64
  content: IyEvYmluL3NoCmNhdCA8PEVPRgouLS0tLS0tLS0tLgp8Li0tLS0tLS0ufAp8fEhBTDkwMDB8fAp8Jy0tLS0tLS0nfAp8ICAgICAgICAgfAp8ICAgICAgICAgfCAiSSdtIHNvcnJ5IERhdmUuIgp8IC4tLiAgICAgfCAiSSdtIGFmcmFpZCBJIGNhbid0IGRvIHRoYXQuIgp8ICggbyApICAgfAp8IFxgLScgICAgIHwKfF9fX19fX19fX3wKfColKiUqJSolKnwKfCUqJSolKiUqJXwKfColKiUqJSolKnwKJz09PT09PT09PScKCkVPRgoK
  owner: root:root
  path: /etc/update-motd.d/99-hello
  permissions: '0755'
EOF

clear && \
multipass launch \
  --cpus "1" \
  --disk "30G" \
  --mem "512M" \
  --name "${INSTANCE_NAME}" \
  --cloud-init "${CLOUD_INIT_FILE}"

# Connect to Instance
multipass shell "${INSTANCE_NAME}"

sudo apt-get update -q && \
sudo apt-get upgrade -y -q && \
sudo apt autoremove -y

# Create a dave user
sudo adduser dave --disabled-password

# Configure user to be a sudoer member to facilitate the tests
echo "dave ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/dave

# Change to user dave
sudo su - dave

# Create a hidden directory
mkdir -p "${HOME}/.kube/"

# Create a Private Key
openssl genrsa -out "${USER}.key" 4096

# Certificate Signing Request (CSR) Configuration File
cat <<EOF > csr.cnf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
CN = ${USER}
O = developers

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
EOF

# Generate CSR File
openssl req \
  -config ./csr.cnf \
  -new \
  -key "${USER}.key" \
  -nodes \
  -out "${USER}.csr"

# On Host
export CSR_FILE="dave.csr"

multipass transfer "hal-9000:/home/dave/${CSR_FILE}" "${PWD}/${CSR_FILE}"

# Encoding the CSR file in base64 and set others variables
export CSR_USER="${CSR_FILE%%.csr}" && \
export CSR_NAME="${CSR_USER}-csr" && \
export CSR_BASE64=$(cat ${CSR_FILE} | base64 | tr -d '\n') && \
echo "CSR_USER............: ${CSR_USER}" && \
echo "CSR_NAME............: ${CSR_NAME}" && \
echo "CSR_BASE64 (length).: ${#CSR_BASE64}"

# Substitution of the CSR_BASE64 env variable and creation of the CertificateSigninRequest resource
cat ../templates/csr.yaml | envsubst | kubectl apply -f -

# Check
kubectl get csr "${CSR_NAME}"

# Approve
kubectl certificate approve "${CSR_NAME}"

# Check
kubectl get csr "${CSR_NAME}"

# Extract Certificate
kubectl get csr "${CSR_NAME}" \
  -o jsonpath='{.status.certificate}' \
  | base64 --decode > "${CSR_USER}.crt"

# Show Certificate Information
openssl x509 -in "./${CSR_USER}.crt" -noout -text | grep "Subject:.*"
openssl x509 -in "./${CSR_USER}.crt" -noout -text | less

# Generate User Kube Config File
cat ../templates/kubeconfig.yaml

# User identifier
export CURRENT_CONTEXT=$(kubectl config current-context)
export CLUSTER_NAME="${CURRENT_CONTEXT}"
export CLIENT_CERTIFICATE_DATA=$(kubectl get csr ${CSR_NAME} -o jsonpath='{.status.certificate}')

# Base Command to Extract "server" and "cluster.certificate-authority-data"
BASE_COMMAND="kubectl config view -o jsonpath='{.clusters[?(@.name==\"%s\")].cluster.%s}' --raw"

# Cluster Certificate Authority and API Server endpoint
COMMAND=$(printf "${BASE_COMMAND}" "${CLUSTER_NAME}" "certificate-authority-data") && export CERTIFICATE_AUTHORITY_DATA=$(${COMMAND} | tr -d "'")
COMMAND=$(printf "${BASE_COMMAND}" "${CLUSTER_NAME}" "server")                     && export CLUSTER_ENDPOINT=$(${COMMAND} | tr -d "'")

export CERTIFICATE_AUTHORITY_DATA=$(cat ${HOME}/.minikube/ca.crt | base64 | sed '1d;$d' | tr -d "\n")

clear && \
echo "" && \
echo "USER........................: ${CSR_USER}" && \
echo "CLUSTER_NAME................: ${CLUSTER_NAME}" && \
echo "CLIENT_CERTIFICATE_DATA.....: ${#CLIENT_CERTIFICATE_DATA} (length)" && \
echo "CERTIFICATE_AUTHORITY_DATA..: ${#CERTIFICATE_AUTHORITY_DATA} (length)" && \
echo "CLUSTER_ENDPOINT............: ${CLUSTER_ENDPOINT}" && \
echo ""

# Only show a template with values
cat ../templates/kubeconfig.yaml | envsubst | yq r -

# Save it to a file
cat ../templates/kubeconfig.yaml | envsubst > "config.yaml"

multipass transfer "${PWD}/config.yaml" "hal-9000:/home/ubuntu/config"

cp ${HOME}/.minikube/ca.crt . && \
multipass transfer "${PWD}/ca.crt" "hal-9000:/home/ubuntu/ca.crt"

# Back to User Machine
sudo mv /home/ubuntu/config ${HOME}/.kube/config
sudo mv /home/ubuntu/ca.crt ${HOME}/.kube/minikube-ca.crt
sudo chown -R ${USER}:${USER} /home/dave/.kube/

sudo apt-get update -q && \
sudo curl --silent "https://packages.cloud.google.com/apt/doc/apt-key.gpg" | sudo apt-key add -

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update package list
sudo apt-get update -q

# Set Kubernetes Version
KUBERNETES_DESIRED_VERSION='1.17.7' && \
KUBERNETES_VERSION="$(apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }')" && \
KUBERNETES_IMAGE_VERSION="${KUBERNETES_VERSION%-*}" && \
clear && \
echo "" && \
echo "KUBERNETES_DESIRED_VERSION.: ${KUBERNETES_DESIRED_VERSION}" && \
echo "KUBERNETES_VERSION.........: ${KUBERNETES_VERSION}" && \
echo ""

# Install Kubectl
sudo apt-get install --yes -q \
  kubectl="${KUBERNETES_VERSION}" | grep --invert-match --extended-regexp "^Hit|^Get|^Selecting|^Preparing|^Unpacking" && \
sudo apt-mark hold \
  kubectl

cat <<EOF | tee --append ~/.bashrc

source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
EOF
source ~/.bashrc

# Add the User Private Key to kube config file
kubectl config set-credentials ${USER} \
  --client-key=${USER}.key \
  --embed-certs=true

# Set development as default namespace
kubectl config \
  set-context dave-minikube \
  --namespace=development

# Try to get Pods
kubectl get pods -n development
kubectl get pods -n default

# Check if the user can create a Deployment on namespace development
kubectl auth can-i create deployments --namespace development

# Create a Deployment and a Service
mkdir nginx && cd nginx

cat <<EOF > nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
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
  name: nginx
  namespace: development
spec:
  selector:
    app: nginx
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 32080
EOF

kubectl apply -f .

watch kubectl -n development get deploy,pods,services -o wide
