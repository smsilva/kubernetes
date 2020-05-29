# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 5zigmr.6vj9jntboaz2zjll \
  --discovery-token-ca-cert-hash sha256:ffb3e0938ebe1e48cf192013bea0467edfa41b771cb2adcb28588261ebdccf9e \
  --v 1
