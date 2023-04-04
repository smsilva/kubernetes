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
sysctl --system > /dev/null
