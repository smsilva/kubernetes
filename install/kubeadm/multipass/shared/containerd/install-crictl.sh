#!/bin/bash
kubernetes_version="${1:-1.32}"

apt-get update --quiet && \
apt-get install --yes \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg

# Get Google Cloud Apt Key
mkdir --parents --mode 755 /etc/apt/keyrings

curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --url "https://pkgs.k8s.io/core:/stable:/v${kubernetes_version?}/deb/Release.key" \
| gpg \
  --dearmor \
  --yes \
  --output /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Allow unprivileged APT programs to read this keyring
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes Repository
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${kubernetes_version?}/deb/ /
EOF

# Refresh package list
apt update --quiet

# Configure crictl
cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

groupadd containerd

chgrp containerd /run/containerd/containerd.sock

# Run as non-root user:
cat <<EOF

Run as non-root user:

  sudo usermod \
    --append \
    --groups containerd \
    \${USER}

EOF
