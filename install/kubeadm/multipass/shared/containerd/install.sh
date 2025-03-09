#!/bin/bash
cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system &> /dev/null

## Set up the repository
### Install packages to allow apt to use a repository over HTTPS
apt-get remove \
  containerd \
  docker \
  docker-compose-plugin \
  docker-engine \
  docker.io \
  runc &> /dev/null

apt-get update -qq

apt-get install -qq \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common \
  --yes

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

architecture=$(dpkg --print-architecture)
  
source /etc/os-release

cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.list
deb [arch=${architecture?} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME?} stable
EOF

## Install containerd
apt-get update -q && \
apt-get install -y -q containerd.io

# Configure containerd
mkdir -p /etc/containerd && \
containerd config default > /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd

containerd --version | awk '{ print $2, $3 }'
