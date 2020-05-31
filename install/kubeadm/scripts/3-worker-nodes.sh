# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token wlnkan.if22ton4xi5gfpn0 \
  --discovery-token-ca-cert-hash sha256:0439bd3b876c85e6eb8fbeba6684c7d6c7e012c1be202c324a3c4bcce193e513 \
  --v 1
