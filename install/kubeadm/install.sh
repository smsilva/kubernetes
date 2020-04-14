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

# Execute an Update
sudo apt update

# Set Kubernetes Version
export KUBERNETES_DESIRED_VERSION='1.17'
export KUBERNETES_VERSION="$(echo -n $(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }'))"
export KUBERNETES_BASE_VERSION="$(echo ${KUBERNETES_VERSION} | cut -d- -f 1)"

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

# Preloading Control Plane Images
kubeadm config images pull

# Installing Control Plane on the First Control Plane Node (master-1)
NETWORK_INTERFACE_NAME='enp0s8'
LOCAL_IP_ADDRESS="$(ip -4 addr show ${NETWORK_INTERFACE_NAME} | grep "inet" | head -1 | awk '{print $2}' | cut -d/ -f1)"

export LOAD_BALANCER_DNS='lb'
export LOAD_BALANCER_IP='192.168.5.30'
export LOAD_BALANCER_PORT='6443'

echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo "LOAD_BALANCER_DNS..........: ${LOAD_BALANCER_DNS}" && \
echo "LOAD_BALANCER_IP...........: ${LOAD_BALANCER_IP}" && \
echo "LOAD_BALANCER_PORT.........: ${LOAD_BALANCER_PORT}" && \
echo ""

# Test Connectivity to Loadbalancer
nc -v ${LOAD_BALANCER_IP} ${LOAD_BALANCER_PORT}

# Initialize master-1
sudo kubeadm init \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --control-plane-endpoint "${LOAD_BALANCER_DNS}:${LOAD_BALANCER_PORT}" \
  --kubernetes-version "${KUBERNETES_BASE_VERSION}" \
  --upload-certs

# To start using your cluster, you need to run the following as a regular user:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install the Weave CNI Plugin
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# Watch Nodes and Pods
watch -n 2 '
  kubectl get nodes -o wide && \
  echo "" && \
  kubectl get pods -n kube-system -o wide'

# Add Another Control Plane
# Get this command from the Ouput of the First Control Plane
NETWORK_INTERFACE_NAME='enp0s8' && \
LOCAL_IP_ADDRESS="$(ip -4 addr show ${NETWORK_INTERFACE_NAME} | grep "inet" | head -1 | awk '{print $2}' | cut -d/ -f1)" && \
echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo ""

sudo kubeadm join lb:6443 \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --token q9uk2o.gdq3i1oilvmgv1mr \
  --discovery-token-ca-cert-hash sha256:99ce6a0d5bc86d7a7de5c1a803362f4d78232c85e48543335bdc69c2567f666c \
  --control-plane \
  --certificate-key 23faca0066ee2746f6994285de2b76daaa9b42e550572211e1e914643c006ffa \
  --v 5

# Add a Node
# Get this command from the Ouput of the First Control Plane
sudo kubeadm join lb:6443 \
  --token q9uk2o.gdq3i1oilvmgv1mr \
  --discovery-token-ca-cert-hash sha256:99ce6a0d5bc86d7a7de5c1a803362f4d78232c85e48543335bdc69c2567f666c

# Join Control Plane (master-2 and master-3)
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
