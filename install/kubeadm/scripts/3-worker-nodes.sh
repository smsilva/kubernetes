# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token uojo7w.yns0c16xkh6kbc5d \
  --discovery-token-ca-cert-hash sha256:ecd91606aedeaad7435c074fd2fe58901cf638da435d7e659a06d714daeef16e \
  --v 3
