# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 5cwx97.qhdguv30e2puhl8e \
  --discovery-token-ca-cert-hash sha256:b87f95ddde0c93f2ec2059079e1f73eed16f6f2e1251eb15ea224259ac676d42 \
  --v 3
