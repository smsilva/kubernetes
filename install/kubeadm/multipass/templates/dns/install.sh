#!/bin/bash
FORWARD_FILE="forward.${DOMAIN_NAME}"
REVERSE_FILE="reverse.${DOMAIN_NAME}"

cp /shared/dns/named.conf.options /etc/bind/
cp /shared/dns/named.conf.local /etc/bind/
cp /shared/dns/"forward.${DOMAIN_NAME}" /etc/bind/
cp /shared/dns/"reverse.${DOMAIN_NAME}" /etc/bind/

systemctl restart bind9
systemctl enable bind9

ufw allow 53

named-checkconf /etc/bind/named.conf.local
named-checkzone ${DOMAIN_NAME} /etc/bind/"forward.${DOMAIN_NAME}"
named-checkzone ${DOMAIN_NAME} /etc/bind/"reverse.${DOMAIN_NAME}"
