#!/bin/bash
DOMAIN_NAME=$1
MASTER_IP_START=$2
MASTER_NODES_COUNT=$3
NODE_IP_START=$4
WORKER_NODES_COUNT=$5
IP_NETWORK=$6
IP_NETWORK_REVERSE=$(awk '{print $3,$2,$1 }' FS='.' OFS='.' <<< ${IP_NETWORK})
IP_DNS=$7
GLUSTERFS_NODES_COUNT=$8
GLUSTERFS_IP_START=$9

echo "DOMAIN_NAME...........: ${DOMAIN_NAME}"
echo "MASTER_IP_START.......: ${MASTER_IP_START}"
echo "MASTER_NODES_COUNT....: ${MASTER_NODES_COUNT}"
echo "NODE_IP_START.........: ${NODE_IP_START}"
echo "WORKER_NODES_COUNT....: ${WORKER_NODES_COUNT}"
echo "IP_NETWORK............: ${IP_NETWORK}"
echo "IP_NETWORK_REVERSE....: ${IP_NETWORK_REVERSE}"
echo "IP_DNS................: ${IP_DNS}"
echo "GLUSTERFS_NODES_COUNT.: ${GLUSTERFS_NODES_COUNT}"
echo "GLUSTERFS_IP_START....: ${GLUSTERFS_IP_START}"

apt-get install \
  bind9 \
  bind9utils \
  bind9-doc \
  dnsutils

mkdir bind && cd bind

cat <<EOF > named.conf.options
options {
        directory "/var/cache/bind";
        auth-nxdomain no;    # conform to RFC1035
     // listen-on-v6 { any; };
        listen-on port 53 { localhost; ${IP_NETWORK}0/24; };
        allow-query { localhost; ${IP_NETWORK}0/24; };
        forwarders { 8.8.8.8; };
        recursion yes;
        };
EOF

cat <<EOF > named.conf.local
zone    "${DOMAIN_NAME}"   {
        type master;
        file    "/etc/bind/forward.${DOMAIN_NAME}";
 };

zone   "${IP_NETWORK_REVERSE}.in-addr.arpa"        {
       type master;
       file    "/etc/bind/reverse.${DOMAIN_NAME}";
 };
EOF

FORWARD_FILE="forward.${DOMAIN_NAME}"

cat <<EOF > "${FORWARD_FILE}"
\$TTL    604800

@            IN      SOA primary.${DOMAIN_NAME}. root.primary.${DOMAIN_NAME}. (
                              6         ; Serial
                         604820         ; Refresh
                          86600         ; Retry
                        2419600         ; Expire
                         604600 )       ; Negative Cache TTL

;Name Server Information
@            IN       NS      primary.${DOMAIN_NAME}.

;IP address of Your Domain Name Server(DNS)
primary      IN       A       ${IP_DNS}

;A Record for Host names
dns          IN       A       ${IP_DNS}
lb           IN       A       ${IP_NETWORK}${MASTER_IP_START}
loadbalancer IN       CNAME   lb
masters      IN       CNAME   lb
k8s          IN       CNAME   lb
cluster      IN       CNAME   lb
EOF

for ((line = 1; line <= ${MASTER_NODES_COUNT}; line++)); do
  echo "master-${line}     IN       A       ${IP_NETWORK}$((${MASTER_IP_START} + ${line}))" >> "${FORWARD_FILE}"
done

for ((line = 1; line <= ${WORKER_NODES_COUNT}; line++)); do
  echo "worker-${line}     IN       A       ${IP_NETWORK}$((${NODE_IP_START} + ${line}))" >> "${FORWARD_FILE}"
done

for ((line = 1; line <= ${GLUSTERFS_NODES_COUNT}; line++)); do
  echo "gluster-${line}    IN       A       ${IP_NETWORK}$((${GLUSTERFS_IP_START} + ${line}))" >> "${FORWARD_FILE}"
done

echo "*.apps       IN       CNAME   lb" >> "${FORWARD_FILE}"

REVERSE_FILE="reverse.${DOMAIN_NAME}"

cat <<EOF > "${REVERSE_FILE}"
\$TTL    604800
@       IN      SOA     ${DOMAIN_NAME}. root.${DOMAIN_NAME}. (
                             21         ; Serial
                         604820         ; Refresh
                          864500        ; Retry
                        2419270         ; Expire
                         604880 )       ; Negative Cache TTL

;Your Name Server Info
@                   IN      NS      primary.${DOMAIN_NAME}.
primary             IN      A       ${IP_DNS}

;Reverse Lookup for Your DNS Server
${IP_DNS##*.}       IN      PTR     primary.${DOMAIN_NAME}.

;PTR Record IP address to HostName
${IP_DNS##*.}       IN      PTR     dns.${DOMAIN_NAME}.
${MASTER_IP_START}      IN      PTR     lb.${DOMAIN_NAME}.
${MASTER_IP_START}      IN      PTR     loadbalancer.${DOMAIN_NAME}.
EOF

for ((line = 1; line <= ${MASTER_NODES_COUNT}; line++)); do
  echo "$((${MASTER_IP_START} + ${line}))      IN      PTR     master-${line}.${DOMAIN_NAME}." >> "${REVERSE_FILE}"
done

for ((line = 1; line <= ${WORKER_NODES_COUNT}; line++)); do
  echo "$((${NODE_IP_START} + ${line}))      IN      PTR     worker-${line}.${DOMAIN_NAME}." >> "${REVERSE_FILE}"
done

for ((line = 1; line <= ${GLUSTERFS_NODES_COUNT}; line++)); do
  echo "$((${GLUSTERFS_IP_START} + ${line}))      IN      PTR     gluster-${line}.${DOMAIN_NAME}." >> "${REVERSE_FILE}"
done

mv named.conf.options /etc/bind/
mv named.conf.local /etc/bind/
mv "${FORWARD_FILE}" /etc/bind/
mv "${REVERSE_FILE}" /etc/bind/

systemctl restart bind9
systemctl enable bind9

ufw allow 53

named-checkconf /etc/bind/named.conf.local
named-checkzone ${DOMAIN_NAME} /etc/bind/"${FORWARD_FILE}"
named-checkzone ${DOMAIN_NAME} /etc/bind/"${REVERSE_FILE}"
