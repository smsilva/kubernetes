#!/bin/bash
set -e
IFNAME=$1
ADDRESS="$(ip -4 addr show ${IFNAME} | grep "inet" | head -1 | awk '{print $2}' | cut -d/ -f1)"
sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

# remove ubuntu-bionic entry
sed -e '/^.*ubuntu-bionic.*/d' -i /etc/hosts

# Update /etc/hosts about other hosts
cat >> /etc/hosts <<EOF
192.168.5.30 lb
192.168.5.31 master-1
192.168.5.32 master-2
192.168.5.33 master-3
192.168.5.41 worker-1
192.168.5.42 worker-2
192.168.5.43 worker-3
EOF
