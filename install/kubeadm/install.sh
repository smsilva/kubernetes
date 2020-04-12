# Install HAProxy
sudo apt update -y && \
sudo apt upgrade -y && \
sudo apt autoremove

sudo apt install -y \
  haproxy

sudo cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
frontend kubernetes
    bind 192.168.5.30:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 192.168.5.111:6443 check fall 3 rise 2
    server master-2 192.168.5.112:6443 check fall 3 rise 2
    server master-3 192.168.5.113:6443 check fall 3 rise 2
EOF

# Restart HAProxy Service
sudo service haproxy restart

# Create Virtual Box Machines with:
#   Network Interfaces:
#   - 1 NAT
#       - ssh      TCP 127.0.0.1 22111 22
#       - tcp27111 TCP           27111 22
#   - 1 Host Only Adapter (create a virtual network before)

# Copy Public SSH Key
ssh-copy-id silvios@127.0.0.1 -p 22111

# Login into Server - Master 1
ssh silvios@127.0.0.1 -p 22111

# Update /etc/hosts with the local IP
NETWORK_INTERFACE_NAME='enp0s3'
ADDRESS="$(ip -4 addr show ${NETWORK_INTERFACE_NAME} | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
sudo sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

# remove ubuntu-bionic entry if exists
sudo sed -e '/^.*ubuntu-bionic.*/d' -i /etc/hosts

# Update /etc/hosts with other hosts addresses
sudo cat >> /etc/hosts <<EOF
192.168.5.111  master-1
192.168.5.112  master-2
192.168.5.113  master-3
192.168.5.121  worker-1
192.168.5.122  worker-2
192.168.5.123  worker-3
192.168.5.30  lb
EOF

# Must Disable SWAP
sudo swapoff -a

# Enable Forward Traffic
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# Enable Configuration
sysctl --system

# Update
sudo apt update -y && \
sudo apt upgrade -y && \
sudo apt autoremove -y

# Install Docker Community Edition
cd /tmp
sudo curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh /tmp/get-docker.sh

# Configure non Root User to be able to use docker command without sudo
sudo usermod -aG docker ${USER}

# Logoff to change take effect
exit

# Logon again and test docker command
docker ps

# Master Nodes
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
export LOAD_BALANCER_DNS='lb'
export LOAD_BALANCER_IP='192.168.5.30'
export LOAD_BALANCER_PORT='6443'

echo "" && \
echo "LOAD_BALANCER_DNS..........: ${LOAD_BALANCER_DNS}" && \
echo "LOAD_BALANCER_IP...........: ${LOAD_BALANCER_IP}" && \
echo "LOAD_BALANCER_PORT.........: ${LOAD_BALANCER_PORT}" && \
echo ""

# Test Connectivity to Loadbalancer
nc -v ${LOAD_BALANCER_IP} ${LOAD_BALANCER_PORT}

# Initialize master-1
sudo kubeadm init \
  --apiserver-advertise-address "192.168.5.111" \
  --control-plane-endpoint "${LOAD_BALANCER_DNS}:${LOAD_BALANCER_PORT}" \
  --kubernetes-version "${KUBERNETES_BASE_VERSION}" \
  --upload-certs

# To start using your cluster, you need to run the following as a regular user:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Check Nodes
kubectl get nodes -o wide

# Check Pods
kubectl get pods -n kube-system -o wide

# Install the Weave CNI Plugin
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# Join Control Plane (master-2 and master-3)
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf $HOME/.kube/config

# Add Another Control Plane
# Get this command from the Ouput of the First Control Plane
sudo kubeadm join lb:6443 \
  --apiserver-advertise-address "192.168.5.113" \
  --token ux1qi2.nawuo8brwk23zy8i \
  --discovery-token-ca-cert-hash sha256:c9932de3bc1d2cdcfe60054f81bae8ac4f342a65074cc13d14d681e6dc6fa848 \
  --control-plane \
  --certificate-key a0e39b4c81f5bc410f5ce2eb32af331e8b529709678e4b129ab962d0a30ad2bc \
  --v 5

# Add a Node
# Get this command from the Ouput of the First Control Plane
sudo kubeadm join lb:6443 \
  --token ux1qi2.nawuo8brwk23zy8i \
  --discovery-token-ca-cert-hash "sha256:c9932de3bc1d2cdcfe60054f81bae8ac4f342a65074cc13d14d681e6dc6fa848" \
  --v 5
