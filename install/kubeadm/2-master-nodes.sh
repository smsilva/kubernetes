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

NODE_NAME=$(hostname -s) && \
sudo kubeadm init \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --kubernetes-version "${KUBERNETES_BASE_VERSION}" \
  --control-plane-endpoint "${LOAD_BALANCER_DNS}:${LOAD_BALANCER_PORT}" \
  --upload-certs

printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))

# Copy token information like those 3 lines below and paste at the end of this file and into 3-worker-nodes.sh file. 
  --token 69qawj.xcghgjhqkx4ifwd4 \
  --discovery-token-ca-cert-hash sha256:5b995e595271f940bc3c7198ff05048aa43cae5522e47b9baa8ba13d5d730975 \
  --certificate-key f8198522b008eddcc259f46197c8dc02a3a638b7572768a395fe7411806c4063

# Set Default Namespace to kube-system
kubectl config set-context --current --namespace kube-system

CUSTOM_COLUMNS_NODES_FILE="~/.kube/custom-columns-node.template"

cat <<EOF > "${CUSTOM_COLUMNS_NODES_FILE}"
NAME           STATUS                                               INTERNAL_IP                                        VERSION
.metadata.name .status.conditions[?(@.type=="Ready")].reason .status.addresses[?(@.type=="InternalIP")].address .status.nodeInfo.kubeletVersion
EOF

echo "PATH=${PATH}:~/bin/" >> ~/.bashrc

source ~/.bashrc

cat <<EOF > ~/bin/kubectl-nodes
#!/bin/bash
NODES=$*

CUSTOM_COLUMNS_NODES_FILE="/home/vagrant/.kube/custom-columns-node.template"

kubectl get nodes ${NODES} \
  --output custom-columns-file="${CUSTOM_COLUMNS_NODES_FILE}" | sed 's/KubeletReady/Ready/;s/NodeStatusUnknown/NotReady/' | column -t
EOF

chmod +x ~/bin/kubectl-nodes

# Watch Nodes and Pods from kube-system namespace
watch -n 3 '
  kubectl nodes && \
  echo " " && \
  kubectl get deployments,pods,services,endpoints -o wide'

# Install the Weave CNI Plugin
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
CNI_ADD_ON_FILE="cni-add-on-weave.yaml" && \
wget \
  "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" \
  --output-document "${CNI_ADD_ON_FILE}" \
  --quiet && \
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
  --control-plane \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --token 69qawj.xcghgjhqkx4ifwd4 \
  --discovery-token-ca-cert-hash sha256:5b995e595271f940bc3c7198ff05048aa43cae5522e47b9baa8ba13d5d730975 \
  --certificate-key f8198522b008eddcc259f46197c8dc02a3a638b7572768a395fe7411806c4063

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
