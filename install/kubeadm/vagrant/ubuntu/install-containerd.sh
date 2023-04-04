#!/bin/bash
cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/80-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system > /dev/null

## Set up the repository
### Install packages to allow apt to use a repository over HTTPS
apt-get update -qqq && \
  apt-get install -y -qqq \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common &> /dev/null

## Add Docker’s official GPG key
wget \
  --quiet \
  --output-document "/etc/apt/trusted.gpg.d/docker.asc" \
  "https://download.docker.com/linux/ubuntu/gpg"

## Add Docker apt repository.
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release --codename --short) \
    stable" &> /dev/null

## Install containerd
apt-get update -qqq && \
apt-get install -y -qqq containerd.io &> /dev/null

# Configure containerd
mkdir -p /etc/containerd && \
containerd config default > /etc/containerd/config.toml

# Configuring the systemd cgroup driver
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd

containerd --version | awk '{ print $2, $3 }'
