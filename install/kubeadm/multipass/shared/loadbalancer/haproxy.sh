#!/bin/bash
apt-get update
apt-get install --yes build-essential

HAPROXY_BASE_VERSION="2.1.7"
HAPROXY_VERSION="${HAPROXY_BASE_VERSION%.*}"

echo "HAPROXY_BASE_VERSION...: ${HAPROXY_BASE_VERSION}"
echo "HAPROXY_VERSION........: ${HAPROXY_VERSION}"

FILE="haproxy-${HAPROXY_BASE_VERSION}.tar.gz"

wget http://www.haproxy.org/download/${HAPROXY_VERSION}/src/${FILE}

tar xvf ${FILE}

useradd haproxy

cd haproxy-${HAPROXY_BASE_VERSION}

make TARGET=linux-glibc

cp haproxy /usr/sbin/haproxy

make install

mkdir -p /etc/haproxy/

cp /shared/loadbalancer/haproxy.cfg /etc/haproxy/haproxy.cfg

systemctl enable haproxy

systemctl start haproxy
