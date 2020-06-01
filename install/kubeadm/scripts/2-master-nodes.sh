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
  --token ina84f.l9iwjyh1a9nxuleo \
  --discovery-token-ca-cert-hash sha256:931913f5838058e4d6ae1f198a6f9156acf17a703689ed7b79a2d4d2510e4f49 \
  --certificate-key f4738ae4b6d1b29aad0ede6ff9b46a5dfb5d12b814ab548f0761a0e432a7f899
  
# Watch Nodes and Pods from kube-system namespace
watch 'kubectl get nodes,pods,services -o wide -n kube-system'

# Install the Weave CNI Plugin
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
CNI_ADD_ON_FILE="cni-add-on-weave.yaml" && \
wget \
  "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" \
  --output-document "${CNI_ADD_ON_FILE}" \
  --quiet && \
kubectl apply -f "${CNI_ADD_ON_FILE}"

# Adding a Control Plane Node
LOCAL_IP_ADDRESS=$(grep $(hostname -s) /etc/hosts | head -1 | awk '{ print $1 }') && \
echo "" && echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --control-plane \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --v 1 \
  --token ina84f.l9iwjyh1a9nxuleo \
  --discovery-token-ca-cert-hash sha256:931913f5838058e4d6ae1f198a6f9156acf17a703689ed7b79a2d4d2510e4f49 \
  --certificate-key f4738ae4b6d1b29aad0ede6ff9b46a5dfb5d12b814ab548f0761a0e432a7f899

# Optional - Ingress HAProxy Controller
# https://github.com/jcmoraisjr/haproxy-ingress
# https://haproxy-ingress.github.io/docs/getting-started/
# https://haproxy-ingress.github.io/docs/configuration/keys/
kubectl create -f https://haproxy-ingress.github.io/resources/haproxy-ingress.yaml

for NODE in master-{1..3}; do
  kubectl label node ${NODE} role=ingress-controller
done

# Optional - Configure Vim to use yaml format a little bit better
cat <<EOF >> .vimrc
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
EOF

# Optional - bat
BAT_VERSION="0.15.1" && \
BAT_DEB_FILE="bat_${BAT_VERSION}_amd64.deb" && \
wget "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/${BAT_DEB_FILE}" \
  --output-document "${BAT_DEB_FILE}" && \
sudo dpkg -i "${BAT_DEB_FILE}" && rm "${BAT_DEB_FILE}" && \
echo "alias cat='bat -p'" >> ~/.bash_aliases && source ~/.bash_aliases && bat --version

# Optional - jq
sudo apt install jq -y

# Optional - yq
sudo snap install yq

# Reset Node Config (if needed)
sudo kubeadm reset -f && \
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
