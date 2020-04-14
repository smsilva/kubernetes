#!/bin/bash

apt-get install -y \
  haproxy

cat <<EOF | tee /etc/haproxy/haproxy.cfg
frontend kubernetes
    bind 192.168.5.10:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 192.168.5.11:6443 check fall 3 rise 2
    server master-2 192.168.5.12:6443 check fall 3 rise 2
    server master-3 192.168.5.13:6443 check fall 3 rise 2
EOF

service haproxy restart
