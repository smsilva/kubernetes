# Installing Control Plane on the First Control Plane Node (master-1)
LOCAL_IP_ADDRESS=$(grep $(hostname -s) /etc/hosts | awk '{ print $1 }')
NETWORK_INTERFACE_NAME=$(ip addr show | grep ${LOCAL_IP_ADDRESS} | awk '{ print $7 }')
LOAD_BALANCER_PORT='6443'
LOAD_BALANCER_DNS='lb'

echo "" && \
echo "NETWORK_INTERFACE_NAME.....: ${NETWORK_INTERFACE_NAME}" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo "ADVERTISE_ADDRESS..........: ${LOAD_BALANCER_DNS}:${LOAD_BALANCER_PORT}" && \
echo "KUBERNETES_BASE_VERSION....: ${KUBERNETES_BASE_VERSION}" && \
echo ""

# Initialize master-1 (Take note of the two Join commands)
SECONDS=0

sudo kubeadm init \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --kubernetes-version "${KUBERNETES_BASE_VERSION}" \
  --control-plane-endpoint "${LOAD_BALANCER_DNS}:${LOAD_BALANCER_PORT}" \
  --upload-certs

printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))

# Copy token information like those 3 lines below and paste at the end of this file and into 3-worker-nodes.sh file. 
#
#   --token f0818g.r9fakwhksxmbj0ui \
#   --discovery-token-ca-cert-hash sha256:5037f60906c7dd6ff1fa7fa606ab8d7b62ab164bcf2e52b19f19acd929b7d651 \
#   --certificate-key d654f4c9a4337f50cf4cfe8ccab0b5a7ff3a31c1dbdece9142dca81689d45546
#

# Watch Nodes and Pods from kube-system namespace
watch '
  kubectl get nodes -o wide && \
  echo "" && \
  kubectl get pods -n kube-system -o wide'

# Install the Weave CNI Plugin
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
CNI_ADD_ON_FILE="cni-add-on-weave.yaml" && \
wget \
  --quiet \
  "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" \
  --output-documen "${CNI_ADD_ON_FILE}" && \
kubectl apply -f "${CNI_ADD_ON_FILE}"

# Adding a Control Plane Node
LOCAL_IP_ADDRESS=$(grep $(hostname -s) /etc/hosts | head -1 | cut -d " " -f 1)

echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo ""

# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
#   - certificate-key
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --v 3 \
  --control-plane \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --token eql8x7.frxy06rj6ijbry3w \
  --discovery-token-ca-cert-hash sha256:c9fba29f17ccd845fb065491f10b9472faac23c2f59d6f9754c63ca00e8b3121 \
  --certificate-key 6b3f7575c3bccabab85f5a475d237c5570e0c7a360e1f8ab12fd8daf22520917

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
