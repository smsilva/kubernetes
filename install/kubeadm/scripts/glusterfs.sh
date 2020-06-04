#!/bin/bash

GLUSTERFS_NODES_COUNT=3
DOMAIN_NAME="example.com"

for ((line = 1; line <= ${GLUSTERFS_NODES_COUNT}; line++)); do
  gluster peer probe "gluster-${line}.${DOMAIN_NAME}"
done

gluster peer status

# From any GlusterFS Node
gluster volume create "gv0" replica "3" \
  "gluster-1:/data/brick1/gv0" \
  "gluster-2:/data/brick1/gv0" \
  "gluster-3:/data/brick1/gv0"

gluster volume info

gluster volume start gv0

# Test
mount -t glusterfs gluster-1:/gv0 /mnt

for file in {01..05}; do
  for line in {01..50}; do
    echo "line ${line}" >> /mnt/file-${file}
  done
done

# Client Install

# Add the FUSE loadable kernel module (LKM) to the Linux kernel:
modprobe fuse

# Verify that the FUSE module is loaded:
dmesg | grep -i fuse

# Install OpenSSH Server on each client using the following command:
apt-get install openssh-server vim wget

# Download the latest GlusterFS .deb file and checksum to each client.
https://www.gluster.org/download/

# Check file
md5sum GlusterFS_DEB_file.deb

# Uninstall GlusterFS v3.1 (or an earlier version) from the client using the following command:
dpkg -r glusterfs

# Install Gluster Native Client on the client using the following command:
dpkg -i GlusterFS_DEB_file

# Ensure that TCP and UDP ports 24007 and 24008 are open on all Gluster servers. Apart from these ports, you need to open one port for each brick starting from port 49152 (instead of 24009 onwards as with previous releases)
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 24007:24008 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 49152:49156 -j ACCEPT

# PPA Config
add-apt-repository --yes ppa:gluster/glusterfs-7
apt-get update

# Install Client
apt-get install --yes glusterfs-client

mkdir --parents /mnt/glusterfs/gv0

mount -t glusterfs gluster-1.example.com:/gv0 /mnt/glusterfs/gv0

# /etc/fstab
gluster-1.example.com:/gv0 /mnt/glusterfs/gv0 glusterfs defaults,_netdev 0 0
