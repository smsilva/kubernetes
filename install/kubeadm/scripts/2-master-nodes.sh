# Configure Bash Completion
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc

# ATTENTION: We should run these commands ONLY on master-1
KUBERNETES_DESIRED_VERSION='1.18' && \
KUBERNETES_VERSION="$(echo -n $(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }'))" && \
KUBERNETES_BASE_VERSION="${KUBERNETES_VERSION%-*}" && \
LOCAL_IP_ADDRESS=$(grep $(hostname -s) /etc/hosts | awk '{ print $1 }') && \
LOAD_BALANCER_PORT='6443' && \
LOAD_BALANCER_NAME='lb' && \
CONTROL_PLANE_ENDPOINT="${LOAD_BALANCER_NAME}:${LOAD_BALANCER_PORT}"
echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo "CONTROL_PLANE_ENDPOINT.....: ${CONTROL_PLANE_ENDPOINT}" && \
echo "KUBERNETES_BASE_VERSION....: ${KUBERNETES_BASE_VERSION}" && \
echo ""

# Initialize master-1 (Take note of the two Join commands)
SECONDS=0 && \
NODE_NAME=$(hostname -s) && \
sudo kubeadm init \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --kubernetes-version "${KUBERNETES_BASE_VERSION}" \
  --control-plane-endpoint "${CONTROL_PLANE_ENDPOINT}" \
  --upload-certs && \
printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))

# Copy token information like those 3 lines below and paste at the end of this file and into 3-worker-nodes.sh file.
  --token puwovr.m7tobo5irflsb8ri \
  --discovery-token-ca-cert-hash sha256:7b766a9058beb26144eb4470051d29fbb2fec92d5e819f9215cbde142bd4d3dd \
  --certificate-key c70d5930cb810e327f80f9b534c21246c7e035b8e777d1fd5f1ab9b6fdc173c5

# Watch Nodes and Pods from kube-system namespace
watch 'kubectl get nodes,deployments,pods,services -o wide -n kube-system'

# Install the Weave CNI Plugin
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
CNI_ADD_ON_FILE="cni-add-on-weave.yaml" && \
wget \
  "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" \
  --output-document "${CNI_ADD_ON_FILE}" \
  --quiet && \
kubectl apply -f "${CNI_ADD_ON_FILE}"

# Optional
BAT_VERSION="0.15.1" && \
BAT_DEB_FILE="bat_${BAT_VERSION}_amd64.deb" && \
wget "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/${BAT_DEB_FILE}" \
  --output-document "${BAT_DEB_FILE}" \
  --quiet && \
sudo dpkg -i "${BAT_DEB_FILE}" && rm "${BAT_DEB_FILE}" && \
echo "alias cat='bat -p'" >> ~/.bash_aliases && source ~/.bash_aliases

# Adding a Control Plane Node
LOCAL_IP_ADDRESS=$(grep $(hostname -s) /etc/hosts | head -1 | cut -d " " -f 1) && \
echo "" && echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}"

# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
#   - certificate-key
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --control-plane \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --v 5 \
  --token puwovr.m7tobo5irflsb8ri \
  --discovery-token-ca-cert-hash sha256:7b766a9058beb26144eb4470051d29fbb2fec92d5e819f9215cbde142bd4d3dd \
  --certificate-key c70d5930cb810e327f80f9b534c21246c7e035b8e777d1fd5f1ab9b6fdc173c5

# Reset Node Config (if needed)
sudo kubeadm reset -f && \
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
