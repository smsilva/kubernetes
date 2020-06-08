#!/bin/bash
export IPV4_ADDRESS="$1"

echo "IPV4_ADDRESS...............: ${IPV4_ADDRESS}"

# Add a Static Route for Kubernetes Service Communication
envsubst < /home/vagrant/.netplan-vagrant-template.yaml | tee /etc/netplan/50-vagrant.yaml

# Apply Changes
netplan apply
