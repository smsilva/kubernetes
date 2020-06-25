#!/bin/bash

# Disable SWAP
swapoff -a

# Update /etc/fstab remove lines with 'swap'
sed '/swap/d' /etc/fstab -i

# Enable Forward Traffic
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# Enable Configuration
sysctl --system

echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" update
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
