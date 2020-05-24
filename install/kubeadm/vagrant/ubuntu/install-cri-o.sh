#!/bin/bash

# Add modules from the Linux Kernel
modprobe overlay
modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Load settings from all system configuration files
sysctl --system

CRIO_BRANCH="release-1.18"
COMMIT_HASH=$(git ls-remote https://github.com/cri-o/cri-o release-1.18 | cut -c1-9)

curl \
  -f https://storage.googleapis.com/k8s-conform-cri-o/artifacts/crio-${COMMIT_HASH}.tar.gz \
  -o crio.tar.gz

tar -xf crio.tar.gz

mv crio-${COMMIT_HASH} /usr/local/crio/

echo 'export PATH=${PATH}:/usr/local/crio/bin' | sudo tee -a /etc/profile && source /etc/profile

ln -s /usr/local/crio/bin/runc /usr/bin/runc
ln -s /usr/local/crio/bin/conmon /usr/bin/conmon
ln -s /usr/local/crio/bin/pinns /usr/bin/pinns

mkdir -p /usr/share/containers/oci/hooks.d

cat <<EOF | tee > /etc/systemd/system/crio.service
[Unit]
Description=cri-o

[Service]
ExecStart=/usr/local/crio/bin/crio-static

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable crio
systemctl start crio

crictl --runtime-endpoint unix:///var/run/crio/crio.sock version

cp /usr/local/crio/etc/crictl.yaml /etc/crictl.yaml

crictl version
