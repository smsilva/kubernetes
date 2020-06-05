# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token b2m55d.4m6g6hd4h9dcgupi \
  --discovery-token-ca-cert-hash sha256:5f17c0b7fb720ffa16b33fd9d686d1868f4c58fded1ba65238ab15cfc3ad5e55 \
  --v 3
