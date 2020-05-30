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

sysctl --system

## Set up the repository
### Install packages to allow apt to use a repository over HTTPS
apt-get update && \
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

## Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

## Add Docker apt repository.
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release --codename --short) \
    stable"

## Install containerd
apt-get update && \
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd && \
containerd config default > /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd

containerd --version
