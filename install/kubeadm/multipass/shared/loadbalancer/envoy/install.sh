#!/bin/bash

# https://www.getenvoy.io/install/envoy/ubuntu/

set -e

sudo apt-get update -qqq

sudo apt-get install -y -qqq \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common

curl -sL 'https://getenvoy.io/gpg' | sudo apt-key add -

sudo add-apt-repository \
"deb [arch=amd64] https://dl.bintray.com/tetrate/getenvoy-deb \
$(lsb_release -cs) \
stable"

sudo apt-get update && \
  sudo apt-get install -y -qq \
    getenvoy-envoy

envoy --version

sudo mkdir -p /etc/envoy/

sudo cp /shared/loadbalancer/envoy/config.yaml /etc/envoy/config.yaml
sudo cp /shared/loadbalancer/envoy/run.sh      /etc/envoy/run.sh

cat <<EOF | sudo tee /etc/systemd/system/envoy.service &> /dev/null
[Unit]
Description=Envoy Proxy
Requires=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/etc/envoy/run.sh
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable envoy
sudo systemctl start envoy
sudo systemctl status envoy

exit 0

ADDRESS=$1
DOMAIN_NAME=$2
MASTER_IP_START=$3
MASTER_NODES_COUNT=$4

HAPROXY_CONFIG_FILE="/etc/haproxy/haproxy.cfg"
ADDRES_START=$(awk '{ print $1,$2,$3 }' FS='.' OFS='.' <<< ${ADDRESS})

apt-get install -y -qqq \
  haproxy &> /dev/null

mv "${HAPROXY_CONFIG_FILE}" "${HOME}/"

cat <<EOF | tee "${HAPROXY_CONFIG_FILE}"
frontend apps-ingress-80
    bind ${ADDRESS}:80
    mode http
    stats enable
    stats auth admin:MySup3r_Scret!Psswrd@
    stats hide-version
    stats show-node
    stats refresh 60s
    stats uri /stats
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

frontend kubernetes-apiserver-6443
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

cat <<EOF | tee -a "${HAPROXY_CONFIG_FILE}"
frontend apps-nodeport-32080
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
