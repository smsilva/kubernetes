# Configure non Root User to be able to use docker command without sudo
sudo usermod -aG docker ${USER}

# Logoff to change take effect
exit

# Logon again and test docker command
docker ps

# All Nodes
sudo apt update -y && \
sudo apt install -y \
  apt-transport-https \
  curl && \
sudo curl -s "https://packages.cloud.google.com/apt/doc/apt-key.gpg" | sudo apt-key add -

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Execute an Update if Needed
sudo apt update -y

# Set Kubernetes Version
KUBERNETES_DESIRED_VERSION='1.18'
KUBERNETES_VERSION="$(echo -n $(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }'))"
KUBERNETES_BASE_VERSION="$(echo ${KUBERNETES_VERSION} | cut -d- -f 1)"

echo "" && \
echo "KUBERNETES_DESIRED_VERSION.: ${KUBERNETES_DESIRED_VERSION}" && \
echo "KUBERNETES_VERSION.........: ${KUBERNETES_VERSION}" && \
echo "KUBERNETES_BASE_VERSION....: ${KUBERNETES_BASE_VERSION}" && \
echo ""

# Install Kubelet, Kubeadm and Kubectl
sudo apt-get install -y \
  kubeadm=${KUBERNETES_VERSION} \
  kubelet=${KUBERNETES_VERSION} \
  kubectl=${KUBERNETES_VERSION} && \
sudo apt-mark hold \
  kubelet \
  kubeadm \
  kubectl

# Preloading Container Images
if hostname -s | grep "master"&>/dev/null; then
  kubeadm config images pull
else
  docker pull "k8s.gcr.io/kube-proxy:v${KUBERNETES_BASE_VERSION}"
fi

# Installing Control Plane on the First Control Plane Node (master-1)
NETWORK_INTERFACE_NAME='eth1'
LOCAL_IP_ADDRESS="$(ip -4 addr show ${NETWORK_INTERFACE_NAME} | grep "inet" | awk '{print $2}' | cut -d '/' -f1)"
LOAD_BALANCER_PORT='6443'
LOAD_BALANCER_DNS='lb'
LOAD_BALANCER_IP="$(echo -n $(cat /etc/hosts | grep ${LOAD_BALANCER_DNS} | cut -d ' ' -f 1))"

echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo "ADVERTISE_ADDRESS..........: ${LOAD_BALANCER_DNS}:${LOAD_BALANCER_PORT}" && \
echo ""

# Test Connectivity to Loadbalancer
nc -v ${LOAD_BALANCER_DNS} ${LOAD_BALANCER_PORT}

# Initialize master-1 (Take note of the two Join commands)
sudo kubeadm init \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --kubernetes-version "${KUBERNETES_BASE_VERSION}" \
  --control-plane-endpoint "${LOAD_BALANCER_DNS}:${LOAD_BALANCER_PORT}" \
  --upload-certs

# Install the Weave CNI Plugin
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# Watch Nodes and Pods
watch -n 2 '
  kubectl get nodes -o wide && \
  echo "" && \
  kubectl get pods -n kube-system -o wide'

# Adding a Control Plane Node

# Get this command from the Ouput of the First Control Plane
NETWORK_INTERFACE_NAME='eth1' && \
LOCAL_IP_ADDRESS="$(ip -4 addr show ${NETWORK_INTERFACE_NAME} | grep "inet" | head -1 | awk '{print $2}' | cut -d/ -f1)" && \
echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo ""

sudo kubeadm join lb:6443 \
  --v 5 \
  --control-plane \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --token 4txjqb.rdb0czcfbszzg1tp \
  --discovery-token-ca-cert-hash sha256:901a09e2df808f5bfb2db4e37b82b15ba1e59f0db0fa28f2607f79439a2007b6 \
  --certificate-key fcf510e7979c4630d96dbceb5f56f4ea2d38426bf4b0d121342b80eee45ad926

# Adding a Worker Node

# Get this command from the Ouput of the First Control Plane
sudo kubeadm join lb:6443 \
  --token 4txjqb.rdb0czcfbszzg1tp \
  --discovery-token-ca-cert-hash sha256:901a09e2df808f5bfb2db4e37b82b15ba1e59f0db0fa28f2607f79439a2007b6 \
  --v 5

# Join Control Plane (master-2 and master-3)
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config

# To get Another Token

# 1. Upload Certificates and Get Certificate Key. Eg: 4d0b2b218a270030df347f013d8aad4f67d1a60e54cb7130bf17dc8179065982
sudo kubeadm init phase upload-certs --upload-certs

# 2. Create a New Token
sudo kubeadm token create --print-join-command
