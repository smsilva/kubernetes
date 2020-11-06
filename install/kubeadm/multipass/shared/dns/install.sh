#!/bin/bash
DOMAIN=$1
FORWARD_FILE="forward.${DOMAIN}"
REVERSE_FILE="reverse.${DOMAIN}"

cp /shared/dns/named.conf.options /etc/bind/
cp /shared/dns/named.conf.local /etc/bind/
cp /shared/dns/"${FORWARD_FILE}" /etc/bind/
cp /shared/dns/"${REVERSE_FILE}" /etc/bind/

systemctl restart bind9 -q
systemctl enable bind9 -q

ufw allow 53 > /dev/null

named-checkconf /etc/bind/named.conf.local
named-checkzone "${DOMAIN}" /etc/bind/"${FORWARD_FILE}"
named-checkzone "${DOMAIN}" /etc/bind/"${REVERSE_FILE}"
