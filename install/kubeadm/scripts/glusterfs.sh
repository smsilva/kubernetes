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
