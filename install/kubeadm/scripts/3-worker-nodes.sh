# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token l3tpb7.8vppdcejxoxq0jpk \
  --discovery-token-ca-cert-hash sha256:488b572fe50c46271f9c8ceea035490209fc8b55be3089212684240ea155021e \
  --v 1
