#!/bin/bash
DOMAIN=$1
FORWARD_FILE="forward.${DOMAIN}"
REVERSE_FILE="reverse.${DOMAIN}"

sed -i 's|^OPTIONS.*|OPTIONS="-u bind -4"|g' /etc/default/named

cp /shared/dns/named.conf.options /etc/bind/
cp /shared/dns/named.conf.local /etc/bind/
cp /shared/dns/"${FORWARD_FILE}" /etc/bind/
cp /shared/dns/"${REVERSE_FILE}" /etc/bind/

systemctl restart named -q
systemctl enable named -q

ufw allow 53 > /dev/null

named-checkconf /etc/bind/named.conf.local
named-checkzone "${DOMAIN}" /etc/bind/"${FORWARD_FILE}"
named-checkzone "${DOMAIN}" /etc/bind/"${REVERSE_FILE}"
