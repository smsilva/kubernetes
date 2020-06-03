# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 69h7fq.z49owr2v60165fna \
  --discovery-token-ca-cert-hash sha256:859f4ca265326db63b8b9ff0278bf461ddc7e37919ba6fa2d669e6890f0e8f04 \
  --v 3
