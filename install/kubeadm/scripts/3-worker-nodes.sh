# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 8ictb2.m2jivzdf67aybwhg \
  --discovery-token-ca-cert-hash sha256:b92a2166fec16fb76641fff6cfaf89f7440575e81a43b90346d69d15d2a9fbed \
  --v 1
