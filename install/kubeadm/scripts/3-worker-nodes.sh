# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 0ynt9m.x377ny7dw2xiteco \
  --discovery-token-ca-cert-hash sha256:cc57e9cb3339d88b934e98595d3521b6accf2fb99307a9f5fcf845c128dd0067 \
  --v 5
