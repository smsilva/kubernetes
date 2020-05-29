#!/bin/bash
set -e

IFNAME=$1
DOMAIN_NAME=$2
MASTER_IP_START=$3
MASTER_NODES_COUNT=$4

HAPROXY_CONFIG_FILE="/etc/haproxy/haproxy.cfg"

echo "IFNAME..............: ${IFNAME}"
echo "DOMAIN_NAME.........: ${DOMAIN_NAME}"
echo "MASTER_IP_START.....: ${MASTER_IP_START}"
echo "MASTER_NODES_COUNT..: ${MASTER_IP_START}"

ADDRESS="$(ip -4 addr show ${IFNAME} | grep "inet" | head -1 | awk '{ print $2 }' | cut -d/ -f1)"
ADDRES_START=$(echo ${ADDRESS} | awk -F '.' '{ print $1 "." $2 "." $3 }')

echo "ADDRESS.............: ${ADDRESS}" && \
echo "ADDRES_START........: ${ADDRES_START}" && \
echo "HOSTNAME............: ${HOSTNAME}"
echo "HAPROXY_CONFIG_FILE.: ${HAPROXY_CONFIG_FILE}"

apt-get install -y \
  haproxy

cp "${HAPROXY_CONFIG_FILE}" "${HOME}/"

cat <<EOF | tee "${HAPROXY_CONFIG_FILE}"
frontend apps-nodeport-frontend
    bind ${ADDRESS}:32080
    mode http
    default_backend apps-nodeport

backend apps-nodeport
    mode http
    balance roundrobin
    option tcp-check
EOF

for ((line = 1; line <= ${MASTER_NODES_COUNT}; line++)); do
  echo "    server master-${line} master-${line}.${DOMAIN_NAME}:32080 check fall 3 rise 2" >> "${HAPROXY_CONFIG_FILE}"
done

cat <<EOF | tee -a "${HAPROXY_CONFIG_FILE}"

frontend apps-ingress-frontend
    bind ${ADDRESS}:80
    mode http
    default_backend apps-ingress

backend apps-ingress
    mode http
    balance roundrobin
    option tcp-check
EOF

for ((line = 1; line <= ${MASTER_NODES_COUNT}; line++)); do
  echo "    server master-${line} master-${line}.${DOMAIN_NAME}:80 check fall 3 rise 2" >> "${HAPROXY_CONFIG_FILE}"
done

cat <<EOF | tee -a "${HAPROXY_CONFIG_FILE}"

frontend kubernetes-apiserver-frontend
    bind ${ADDRESS}:6443
    option tcplog
    mode tcp
    default_backend kubernetes-apiserver

backend kubernetes-apiserver
    mode tcp
    balance roundrobin
    option tcp-check
EOF

for ((line = 1; line <= ${MASTER_NODES_COUNT}; line++)); do
  echo "    server master-${line} master-${line}.${DOMAIN_NAME}:6443 check fall 3 rise 2" >> "${HAPROXY_CONFIG_FILE}"
done

cat "${HAPROXY_CONFIG_FILE}"

service haproxy restart
