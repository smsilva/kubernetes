#!/bin/bash
SECONDS=0

# Multipass
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
  --cpus "2" \
  --disk "80G" \
  --mem "4G" \
  --name "${INSTANCE_NAME}" \
  --cloud-init "${CLOUD_INIT_FILE}"

multipass shell "${INSTANCE_NAME}"

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
docker images

# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.8.1/kind-linux-amd64
chmod +x ./kind
sudo mkdir -p /usr/local/bin/
sudo install kind /usr/local/bin/
kind version

# kubectl
sudo curl --silent "https://packages.cloud.google.com/apt/doc/apt-key.gpg" | sudo apt-key add -

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update package list
sudo apt-get update -q

# Set Kubernetes Version
KUBERNETES_DESIRED_VERSION='1.18' && \
KUBERNETES_VERSION="$(apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }')" && \
clear && \
echo "" && \
echo "KUBERNETES_DESIRED_VERSION.: ${KUBERNETES_DESIRED_VERSION}" && \
echo "KUBERNETES_VERSION.........: ${KUBERNETES_VERSION}" && \
echo ""

# Install kubectl
sudo apt-get install --yes -qq \
  kubectl="${KUBERNETES_VERSION}" | grep --invert-match --extended-regexp "^Hit|^Get|^Selecting|^Preparing|^Unpacking" && \
sudo apt-mark hold \
  kubectl

# Kind Cluster
kind create cluster

# CNI
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

for deploymentName in $(kubectl -n kube-system get deploy -o name); do
   echo "Waiting for: ${deploymentName}"

   kubectl \
     -n kube-system \
     wait --for condition=available \
     --timeout=120s \
     ${deploymentName};
done

kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

if ! which argocd &> /dev/null; then
  echo "Need to download and install argocd CLI..."

  VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

  echo "Downloading version: ${VERSION}"

  sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64

  sudo chmod +x /usr/local/bin/argocd
fi

for deploymentName in $(kubectl -n argocd get deploy -o name); do
   echo "Waiting for: ${deploymentName}"

   kubectl \
     -n argocd \
     wait --for condition=available \
     --timeout=120s \
     ${deploymentName};
done

kubectl apply -n argocd -f argocd-server-service.yaml

ARGOCD_INITIAL_PASSWORD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d '/' -f 2)
ARGOCD_URL=$(kubectl get nodes -o jsonpath='{ .items[*].status.addresses[?(@.type == "InternalIP")].address}'):32443

clear && \
echo "ARGOCD_URL...............: ${ARGOCD_URL}" && \
echo "ARGOCD_INITIAL_PASSWORD..: ${ARGOCD_INITIAL_PASSWORD}"

argocd login \
  ${ARGOCD_URL} \
  --username admin \
  --password "${ARGOCD_INITIAL_PASSWORD}" \
  --insecure

argocd account update-password \
  --account admin \
  --current-password "${ARGOCD_INITIAL_PASSWORD}" \
  --new-password "anystrongpassword"

kubectl create ns dev

argocd app create nginx \
  --repo https://github.com/smsilva/argocd.git \
  --path nginx \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev

argocd app list

argocd app get nginx

argocd app sync nginx

argocd app set nginx --sync-policy automated
argocd app set nginx --auto-prune
argocd app set nginx --self-heal

for deploymentName in $(kubectl -n dev get deploy -o name); do
   echo "Waiting for: ${deploymentName}"

   kubectl \
     -n dev \
     wait --for condition=available \
     --timeout=90s \
     ${deploymentName};
done

curl $(minikube service nginx -n dev --url) -Is | head -2

elapsed ${SECONDS}

# Access ArgoCD UI
# minikube service argocd-server -n argocd
