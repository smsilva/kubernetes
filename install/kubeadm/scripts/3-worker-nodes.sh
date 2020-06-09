# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname --short) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token zqvyzl.gvjyh9biqqzi02c9 \
  --discovery-token-ca-cert-hash sha256:288b39766f30e89f7c68740d7e33e3a669dac97648358472b634f880448cd7b4 \
  --v 1

# Optional
sudo crictl pull nginx:1.19 && \
sudo crictl pull nginx:1.18 && \
sudo crictl pull yauritux/busybox-curl && \
sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest
