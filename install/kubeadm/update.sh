# Control Plane
CONTROL_PLANE_NODE_NAME="$(hostname -s)"
KUBERNETES_DESIRED_VERSION='1.18'
KUBERNETES_VERSION="$(echo -n $(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }'))"
KUBERNETES_BASE_VERSION="$(echo ${KUBERNETES_VERSION} | cut -d- -f 1)"

echo "" && \
echo "KUBERNETES_DESIRED_VERSION.: ${KUBERNETES_DESIRED_VERSION}" && \
echo "KUBERNETES_VERSION.........: ${KUBERNETES_VERSION}" && \
echo "KUBERNETES_BASE_VERSION....: ${KUBERNETES_BASE_VERSION}" && \
echo ""

sudo apt-get update && \
sudo apt-get install -y \
  --allow-change-held-packages \
  kubeadm=${KUBERNETES_VERSION}

kubectl drain ${CONTROL_PLANE_NODE_NAME} \
  --ignore-daemonsets

# Only on Master-1
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply ${KUBERNETES_BASE_VERSION}

kubectl uncordon ${CONTROL_PLANE_NODE_NAME}

sudo apt-get update && \
sudo apt-get install -y \
  --allow-change-held-packages \
  kubelet=${KUBERNETES_VERSION} \
  kubectl=${KUBERNETES_VERSION}

# Worker Nodes
WORKER_NODE_NAME="$(hostname -s)"
KUBERNETES_DESIRED_VERSION='1.18'
KUBERNETES_VERSION="$(echo -n $(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }'))"
KUBERNETES_BASE_VERSION="$(echo ${KUBERNETES_VERSION} | cut -d- -f 1)"

echo "" && \
echo "KUBERNETES_DESIRED_VERSION.: ${KUBERNETES_DESIRED_VERSION}" && \
echo "KUBERNETES_VERSION.........: ${KUBERNETES_VERSION}" && \
echo "KUBERNETES_BASE_VERSION....: ${KUBERNETES_BASE_VERSION}" && \
echo ""

sudo apt-get update && \
sudo apt-get install -y \
  --allow-change-held-packages \
  kubeadm=${KUBERNETES_VERSION}

# Control Plane
kubectl drain ${WORKER_NODE_NAME} \
  --ignore-daemonsets

# Back to Worker Node
sudo kubeadm upgrade node

sudo apt-get update && \
sudo apt-get install -y \
  --allow-change-held-packages \
  kubelet=${KUBERNETES_VERSION} \
  kubectl=${KUBERNETES_VERSION}

sudo systemctl restart kubelet

# Control Plane
kubectl uncordon ${WORKER_NODE_NAME}
