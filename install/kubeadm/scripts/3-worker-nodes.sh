# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token ina84f.l9iwjyh1a9nxuleo \
  --discovery-token-ca-cert-hash sha256:931913f5838058e4d6ae1f198a6f9156acf17a703689ed7b79a2d4d2510e4f49 \
  --v 1
