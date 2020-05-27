# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token p7xlwo.yh9ro28tubgoqsic \
  --discovery-token-ca-cert-hash sha256:3aa0ce694fd3538b9fd30274015d1734673cceff76afa26631e8d947f033f25a \
  --v 5
