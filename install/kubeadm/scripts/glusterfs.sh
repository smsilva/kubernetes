#!/bin/bash

# From any GlusterFS Node
gluster volume create "gv0" replica "3" \
  "gluster-1:/data/brick1/gv0" \
  "gluster-2:/data/brick1/gv0" \
  "gluster-3:/data/brick1/gv0"

gluster volume info

gluster volume start gv0
