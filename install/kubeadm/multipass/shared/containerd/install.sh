#!/bin/bash
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
br_netfilter
ip_vs
ip_vs_rr
ip_vs_sh
ip_vs_wrr
nf_conntrack
overlay
EOF

modprobe overlay
modprobe br_netfilter

systemctl restart systemd-modules-load.service
systemctl status systemd-modules-load

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/20-kubernetes-cri.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
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
  runc 2> /dev/null

apt-get update

apt-get install \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common \
  --yes

install -m 0755 -d /etc/apt/keyrings

curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --url https://download.docker.com/linux/ubuntu/gpg \
| gpg \
  --dearmor \
  --yes \
  --output /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

architecture=$(dpkg --print-architecture)
  
source /etc/os-release

cat <<EOF | tee /etc/apt/sources.list.d/docker.list
deb [arch=${architecture?} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME?} stable
EOF

## Install containerd
apt-get update --quiet && \
apt-get install --yes --quiet containerd.io

# Configure containerd
mkdir --parents /etc/containerd
containerd config default \
| tee /etc/containerd/config.toml

# Configuring the systemd cgroup driver
sed -i 's|SystemdCgroup = false|SystemdCgroup = true|g' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd

containerd --version | awk '{ print $2, $3 }'
