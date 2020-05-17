#!/bin/bash
set -e

IFNAME=$1

echo "IFNAME...........: ${IFNAME}"

ADDRESS="$(ip -4 addr show ${IFNAME} | grep "inet" | head -1 | awk '{ print $2 }' | cut -d/ -f1)"
ADDRES_START=$(echo ${ADDRESS} | awk -F '.' '{ print $1 "." $2 "." $3 }')

echo "ADDRESS..........: ${ADDRESS}" && \
echo "ADDRES_START.....: ${ADDRES_START}" && \
echo "HOSTNAME.........: ${HOSTNAME}"

sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.example.com ${HOSTNAME}.local/" -i /etc/hosts

hostnamectl set-hostname ${HOSTNAME}.example.com

# Update /etc/hosts about other hosts
# cat >> /etc/hosts <<EOF
# ${ADDRES_START}.10 lb
# ${ADDRES_START}.11 master-1
# ${ADDRES_START}.12 master-2
# ${ADDRES_START}.13 master-3
# ${ADDRES_START}.21 worker-1
# ${ADDRES_START}.22 worker-2
# ${ADDRES_START}.23 worker-3
# EOF
