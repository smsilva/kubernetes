#!/bin/bash
### Install packages to allow apt to use a repository over HTTPS
apt-get remove \
  containerd \
  docker \
  docker-compose-plugin \
  docker-engine \
  docker.io \
  runc

apt-get update -q

apt-get install -q \
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

cat <<EOF | tee /etc/apt/sources.list.d/docker.list
deb [arch=${architecture?} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME?} stable
EOF

## Install containerd
apt-get update -q && \
apt-get install -y -q containerd.io

# Configure containerd
mkdir -p /etc/containerd && \
containerd config default > /etc/containerd/config.toml

# Configuring the systemd cgroup driver
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd

containerd --version | awk '{ print $2, $3 }'
