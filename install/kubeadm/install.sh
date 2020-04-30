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

# Update package list
sudo apt update

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
  echo 'source <(kubectl completion bash)' >> ~/.bashrc
  echo 'alias k=kubectl' >> ~/.bashrc
  echo 'complete -F __start_kubectl k' >> ~/.bashrc
  source ~/.bashrc

  kubeadm config images pull
else
  docker pull "k8s.gcr.io/kube-proxy:v${KUBERNETES_BASE_VERSION}"
fi

# Installing Control Plane on the First Control Plane Node (master-1)
LOCAL_IP_ADDRESS=$(grep $(hostname -s) /etc/hosts | head -1 | cut -d " " -f 1)
NETWORK_INTERFACE_NAME=$(ip addr show | grep ${LOCAL_IP_ADDRESS} | awk '{ print $7 }')
LOAD_BALANCER_PORT='6443'
LOAD_BALANCER_DNS='lb'
LOAD_BALANCER_IP="$(echo -n $(cat /etc/hosts | grep ${LOAD_BALANCER_DNS} | cut -d ' ' -f 1))"

echo "" && \
echo "NETWORK_INTERFACE_NAME.....: ${NETWORK_INTERFACE_NAME}" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo "ADVERTISE_ADDRESS..........: ${LOAD_BALANCER_DNS}:${LOAD_BALANCER_PORT}" && \
echo ""

# Test Connectivity to Loadbalancer
nc -dv ${LOAD_BALANCER_DNS} ${LOAD_BALANCER_PORT}

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
LOCAL_IP_ADDRESS=$(grep $(hostname -s) /etc/hosts | head -1 | cut -d " " -f 1)
NETWORK_INTERFACE_NAME=$(ip addr show | grep ${LOCAL_IP_ADDRESS} | awk '{ print $7 }')

echo "" && \
echo "NETWORK_INTERFACE_NAME.....: ${NETWORK_INTERFACE_NAME}" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo ""

# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
#   - certificate-key
sudo kubeadm join lb:6443 \
  --v 5 \
  --control-plane \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --token ug2dfo.kb4ebl4o2h553bl4 \
  --discovery-token-ca-cert-hash sha256:d451ff2b1811081730a5719a8ebe00fa4c8ded49af70be273f097e63f2cf0399 \
  --certificate-key 005e6d2f884d9faee760857eef42f19e6708d3651e3608d34d9acd9caa98765e

# Adding a Worker Node
#
# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
sudo kubeadm join lb:6443 \
  --token ug2dfo.kb4ebl4o2h553bl4 \
  --discovery-token-ca-cert-hash sha256:d451ff2b1811081730a5719a8ebe00fa4c8ded49af70be273f097e63f2cf0399 \
  --v 5

# Reseting kubeadm config to try again
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config

# To get Another Token

# 1. Upload Certificates and Get Certificate Key. Eg: 4d0b2b218a270030df347f013d8aad4f67d1a60e54cb7130bf17dc8179065982
sudo kubeadm init phase upload-certs --upload-certs

# 2. Create a New Token
sudo kubeadm token create --print-join-command
