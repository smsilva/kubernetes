#!/bin/bash
NETWORK_INTERFACE_NAME="$1"
LOCAL_IP_ADDRESS="$(ip -4 addr show ${NETWORK_INTERFACE_NAME} | grep "inet" | head -1 | awk '{print $2}' | cut -d/ -f1)"

echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}"

# Add a Static Route for Kubernetes Service Communication
echo "      routes:" >> /etc/netplan/50-vagrant.yaml
echo "      - to: 10.96.0.0/16" >> /etc/netplan/50-vagrant.yaml
echo "        via: ${LOCAL_IP_ADDRESS}" >> /etc/netplan/50-vagrant.yaml

# Apply Changes
netplan apply
