# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname --short) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 25jr9f.n5xcucjkc32mszgs \
  --discovery-token-ca-cert-hash sha256:7c3753fb8578fe37a95ddb62db9fac4c96f8ab526dadba237cd64d944eccedb6 \
  --v 3

# Optional
sudo crictl pull nginx:1.19
sudo crictl pull nginx:1.18
sudo crictl pull yauritux/busybox-curl
sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest
