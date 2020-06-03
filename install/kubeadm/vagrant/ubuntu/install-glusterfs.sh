#!/bin/bash
GLUSTERFS_NODES_COUNT=$1
GLUSTERFS_IP_START=$2
DOMAIN_NAME=$3

GLUSTERFS_NODES_COUNT=3
GLUSTERFS_IP_START=30

echo "GLUSTERFS_NODES_COUNT.: ${GLUSTERFS_NODES_COUNT}" && \
echo "GLUSTERFS_IP_START....: ${GLUSTERFS_IP_START}"

mkfs.xfs -i size=512 /dev/sdc
mkdir -p /data/brick1/gv0
echo '/dev/sdc /data/brick1 xfs defaults 1 2' | tee -a /etc/fstab
mount -a && lsblk -p

apt-get install software-properties-common

add-apt-repository --yes ppa:gluster/glusterfs-7
apt update

apt install --yes glusterfs-server

for ((line = 1; line <= ${GLUSTERFS_NODES_COUNT}; line++)); do
  iptables -I INPUT -p all -s "gluster-${line}" -j ACCEPT
done

for ((line = 1; line <= ${GLUSTERFS_NODES_COUNT}; line++)); do
  gluster peer probe "gluster-${line}.${DOMAIN_NAME}"
done

gluster peer status
