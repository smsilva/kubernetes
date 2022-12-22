#!/bin/bash

# As mentioned here:
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

# Disable SWAP
swapoff -a &> /dev/null

# Update /etc/fstab remove lines with 'swap'
sed '/swap/d' /etc/fstab -i

# Enable Configuration
sysctl --system &> /dev/null
