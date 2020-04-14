#!/bin/bash

# HAProxy Install
apt-get install -y \
  haproxy

# HAProxy Configuration
cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
frontend kubernetes
    bind 192.168.5.30:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 192.168.5.31:6443 check fall 3 rise 2
    server master-2 192.168.5.32:6443 check fall 3 rise 2
    server master-3 192.168.5.33:6443 check fall 3 rise 2
EOF

# Restart HAProxy Service
service haproxy restart
