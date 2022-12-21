#!/bin/bash

# As mentioned here:
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

# Disable SWAP
swapoff -a &> /dev/null

# Update /etc/fstab remove lines with 'swap'
sed '/swap/d' /etc/fstab -i

# Enable Forward Traffic
cat <<EOF > /etc/sysctl.d/80-kubernetes-network.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# Enable Configuration
sysctl --system &> /dev/null
