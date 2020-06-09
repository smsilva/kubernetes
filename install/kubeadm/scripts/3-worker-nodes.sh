# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname --short) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token lz1j48.frem3xul39ykidy1 \
  --discovery-token-ca-cert-hash sha256:902a634e7fd74eef21c62a5443624f32a9a022ec3c817686a6b9295a31531c63 \
  --v 3

# Optional
sudo crictl pull nginx:1.19
sudo crictl pull nginx:1.18
sudo crictl pull yauritux/busybox-curl
sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest
