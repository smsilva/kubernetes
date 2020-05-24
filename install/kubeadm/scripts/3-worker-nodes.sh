# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token wmhxjw.1fm8gobad6w52k9a \
  --discovery-token-ca-cert-hash sha256:64f217127e34d21f38a1f15dae2177d1cb61ce7f6d82de1c05a469168240b56c \
  --v 5

######################## Hey!!! Check Container Images after Node Join please!!!

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
