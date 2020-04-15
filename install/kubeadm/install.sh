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
KUBERNETES_DESIRED_VERSION='1.17'
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
  docker pull k8s.gcr.io/kube-proxy:v1.17.4
fi

# Installing Control Plane on the First Control Plane Node (master-1)
NETWORK_INTERFACE_NAME='enp0s8'
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

# Adding a Control Plane Node

# Get this command from the Ouput of the First Control Plane
NETWORK_INTERFACE_NAME='enp0s8' && \
LOCAL_IP_ADDRESS="$(ip -4 addr show ${NETWORK_INTERFACE_NAME} | grep "inet" | head -1 | awk '{print $2}' | cut -d/ -f1)" && \
echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo ""

sudo kubeadm join lb:6443 \
  --control-plane \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --token xjpr7t.0il99eps1qt29ozj \
  --discovery-token-ca-cert-hash sha256:81cb6ea738f3f043f9cae7af9d15d38705b23d4040698d8fe1418ae4d818a65f \
  --certificate-key aca02d990978475a484d8cc0e5fc28211f5b95aabd41730bde6febd193fb439b \
  --v 5

# Adding a Worker Node

# Get this command from the Ouput of the First Control Plane
sudo kubeadm join lb:6443 \
  --token xjpr7t.0il99eps1qt29ozj \
  --discovery-token-ca-cert-hash sha256:81cb6ea738f3f043f9cae7af9d15d38705b23d4040698d8fe1418ae4d818a65f

# Join Control Plane (master-2 and master-3)
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config

# To get Another Token

# 1. Upload Certificates and Get Certificate Key. Eg: 4d0b2b218a270030df347f013d8aad4f67d1a60e54cb7130bf17dc8179065982
sudo kubeadm init phase upload-certs --upload-certs

# 2. Create a New Token
sudo kubeadm token create --print-join-command
