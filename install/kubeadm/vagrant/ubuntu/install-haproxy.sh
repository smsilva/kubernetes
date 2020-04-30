#!/bin/bash
set -e

IFNAME=$1

echo "IFNAME...........: ${IFNAME}"

ADDRESS="$(ip -4 addr show ${IFNAME} | grep "inet" | head -1 | awk '{ print $2 }' | cut -d/ -f1)"
ADDRES_START=$(echo ${ADDRESS} | awk -F '.' '{ print $1 "." $2 "." $3 }')

echo "ADDRESS..........: ${ADDRESS}" && \
echo "ADDRES_START.....: ${ADDRES_START}" && \
echo "HOSTNAME.........: ${HOSTNAME}"

apt-get install -y \
  haproxy

cat <<EOF | tee /etc/haproxy/haproxy.cfg
frontend kubernetes
    bind ${ADDRES_START}.10:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 ${ADDRES_START}.11:6443 check fall 3 rise 2
    server master-2 ${ADDRES_START}.12:6443 check fall 3 rise 2
    server master-3 ${ADDRES_START}.13:6443 check fall 3 rise 2
EOF

service haproxy restart
