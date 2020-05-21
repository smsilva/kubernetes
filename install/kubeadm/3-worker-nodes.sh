# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token rsettg.2t2q7qg6jo08w3cg \
  --discovery-token-ca-cert-hash sha256:2bc955831b6fc8420178ffeeb608c5fbee8e013c2214a13b3932451cd6c5fa9b \
  --v 1

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
