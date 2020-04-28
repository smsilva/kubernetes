#!/bin/bash
set -e
IFNAME=$1

echo "IFNAME...........: ${IFNAME}"

ADDRESS="$(ip -4 addr show ${IFNAME} | grep "inet" | head -1 | awk '{ print $2 }' | cut -d/ -f1)"

echo "ADDRESS..........: ${ADDRESS}"
echo "HOSTNAME.........: ${HOSTNAME}"

sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

echo "CODE.............: $?"

# Update /etc/hosts about other hosts
cat >> /etc/hosts <<EOF
192.168.5.10 lb
192.168.5.11 master-1
192.168.5.12 master-2
192.168.5.13 master-3
192.168.5.21 worker-1
192.168.5.22 worker-2
192.168.5.23 worker-3
EOF

echo "CODE.............: $?"
