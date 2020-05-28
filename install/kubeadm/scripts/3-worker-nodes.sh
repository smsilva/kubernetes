# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token bwd5jj.8di7n41xygk4aa7m \
  --discovery-token-ca-cert-hash sha256:3d8f620006d1a3cb4a6f6212e07f84e224588a4b34a4fa55cdd5e98f6f6a70c2 \
  --v 1
