# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 0mdt83.rhtx3fxsl5wfsew6 \
  --discovery-token-ca-cert-hash sha256:1afea38beb1c2059d9c67d2e3910ef6dff546c3fd2c551762eab757f6ffbb949 \
  --v 3
