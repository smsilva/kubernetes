# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname --short) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token ft16yn.ogrktrhdj1zz1zcl \
  --discovery-token-ca-cert-hash sha256:66431463104a274ab585abfd4aacecc2c5eca233a32de5be80580ca51bc3b0b1 \
  --v 1

# Optional
sudo crictl pull nginx:1.19 && \
sudo crictl pull nginx:1.18 && \
sudo crictl pull yauritux/busybox-curl && \
sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest
