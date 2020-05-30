# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token i34v35.628qnjrwyvh9rvv7 \
  --discovery-token-ca-cert-hash sha256:45499460023073a566f2c37d2af3965453a608a0af6e2e40feaf9b281c9bab00 \
  --v 1
