# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 30a372.cqbwhqwz9vwoypxa \
  --discovery-token-ca-cert-hash sha256:b118694b4bd316cfecfa986175b6799d7a32e7c8e633e6b195cc3ad46e2bdece \
  --v 3
