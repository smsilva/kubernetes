# Installing Control Plane on the First Control Plane Node (master-1)
LOCAL_IP_ADDRESS=$(grep $(hostname -s) /etc/hosts | awk '{ print $1 }')
NETWORK_INTERFACE_NAME=$(ip addr show | grep ${LOCAL_IP_ADDRESS} | awk '{ print $7 }')
LOAD_BALANCER_PORT='6443'
LOAD_BALANCER_DNS='lb'

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
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
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
  --token 46xyy8.pqhgc1823z7gp4h1 \
  --discovery-token-ca-cert-hash sha256:238962e04d9dbe5c78b047a3dc3333cccb91f4ac577e806b4b519ae26b9eb451 \
  --certificate-key 2dca6ec5d117e3b0c46416fd9a5e58af37973833a8c3c869c4ea2737ad357f5b
