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
  --pod-network-cidr="10.217.0.0/16" \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --kubernetes-version "${KUBERNETES_BASE_VERSION}" \
  --control-plane-endpoint "${CONTROL_PLANE_ENDPOINT}" \
  --upload-certs && \
printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))

# Copy token information like those 3 lines below and paste at the end of this file and into 3-worker-nodes.sh file.
  --token uojo7w.yns0c16xkh6kbc5d \
  --discovery-token-ca-cert-hash sha256:ecd91606aedeaad7435c074fd2fe58901cf638da435d7e659a06d714daeef16e \
  --certificate-key dff50dd589e80a76b58ea80f78728def4c0939a870d399b7b359a95832afde0b
  
# Watch Nodes and Pods from kube-system namespace
watch 'kubectl get nodes,pods,services -o wide -n kube-system'

# Install CNI Plugin
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
# kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
kubectl create -f https://raw.githubusercontent.com/cilium/cilium/v1.6/install/kubernetes/quick-install.yaml

# Adding a Control Plane Node
LOCAL_IP_ADDRESS=$(grep $(hostname -s) /etc/hosts | head -1 | awk '{ print $1 }') && \
echo "" && echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --control-plane \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --v 3 \
  --token uojo7w.yns0c16xkh6kbc5d \
  --discovery-token-ca-cert-hash sha256:ecd91606aedeaad7435c074fd2fe58901cf638da435d7e659a06d714daeef16e \
  --certificate-key dff50dd589e80a76b58ea80f78728def4c0939a870d399b7b359a95832afde0b

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

# Optional - Ingress HAProxy Controller
# https://kubernetes.io/docs/concepts/services-networking/ingress/
# https://github.com/jcmoraisjr/haproxy-ingress
# https://haproxy-ingress.github.io/docs/getting-started/
# https://haproxy-ingress.github.io/docs/configuration/keys/
kubectl create -f https://haproxy-ingress.github.io/resources/haproxy-ingress.yaml

for NODE in $(kubectl get nodes -l node-role.kubernetes.io/master="" --no-headers -o custom-columns="NAME:.metadata.name"); do
  kubectl label node ${NODE} role=ingress-controller
done

# Reset Node Config (if needed)
sudo kubeadm reset -f && \
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
