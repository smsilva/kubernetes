# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token puwovr.m7tobo5irflsb8ri \
  --discovery-token-ca-cert-hash sha256:7b766a9058beb26144eb4470051d29fbb2fec92d5e819f9215cbde142bd4d3dd \
  --v 1
