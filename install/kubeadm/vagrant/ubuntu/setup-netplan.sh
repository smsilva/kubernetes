#!/bin/bash
export IP_SERVER="$1"
export DOMAIN_NAME="$2"
export IP_DNS="$3"

# Add a Static Route for Kubernetes Service Communication
envsubst < /home/vagrant/.netplan-vagrant-template.yaml > /etc/netplan/60-vagrant.yaml

# Apply Changes
netplan apply &> /dev/null
