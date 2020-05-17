#!/bin/bash
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
        listen-on port 53 { localhost; 192.168.10.0/24; };
        allow-query { localhost; 192.168.10.0/24; };
        forwarders { 8.8.8.8; };
        recursion yes;
        };
EOF

cat <<EOF > named.conf.local
zone    "example.com"   {
        type master;
        file    "/etc/bind/forward.example.com";
 };

zone   "10.168.192.in-addr.arpa"        {
       type master;
       file    "/etc/bind/reverse.example.com";
 };
EOF

cat <<EOF > forward.example.com
\$TTL    604800

@       IN      SOA     primary.example.com. root.primary.example.com. (
                              6         ; Serial
                         604820         ; Refresh
                          86600         ; Retry
                        2419600         ; Expire
                         604600 )       ; Negative Cache TTL

;Name Server Information
@       IN      NS      primary.example.com.

;IP address of Your Domain Name Server(DNS)
primary IN       A      192.168.10.2

;Mail Server MX (Mail exchanger) Record
example.com. IN  MX  100  mail.example.com.

;A Record for Host names
dns          IN       A       192.168.10.2
lb           IN       A       192.168.10.10
loadbalancer IN       A       192.168.10.10
master-1     IN       A       192.168.10.11
master-2     IN       A       192.168.10.12
master-3     IN       A       192.168.10.13
worker-1     IN       A       192.168.10.21
worker-2     IN       A       192.168.10.22
worker-3     IN       A       192.168.10.23

;CNAME Record
ftp     IN      CNAME    www.example.com.
EOF

cat <<EOF > reverse.example.com
\$TTL    604800
@       IN      SOA     example.com. root.example.com. (
                             21         ; Serial
                         604820         ; Refresh
                          864500        ; Retry
                        2419270         ; Expire
                         604880 )       ; Negative Cache TTL

;Your Name Server Info
@       IN      NS      primary.example.com.
primary IN      A       192.168.10.2

;Reverse Lookup for Your DNS Server
2       IN      PTR     primary.example.com.

;PTR Record IP address to HostName
2       IN      PTR     dns.example.com.
10      IN      PTR     lb.example.com.
10      IN      PTR     loadbalancer.example.com.
11      IN      PTR     master-1.example.com.
12      IN      PTR     master-2.example.com.
13      IN      PTR     master-2.example.com.
21      IN      PTR     worker-1.example.com.
22      IN      PTR     worker-2.example.com.
23      IN      PTR     worker-2.example.com.
EOF

mv named.conf.options /etc/bind/
mv named.conf.local /etc/bind/
mv forward.example.com /etc/bind/
mv reverse.example.com /etc/bind/

systemctl restart bind9
systemctl enable bind9

ufw allow 53

named-checkconf /etc/bind/named.conf.local
named-checkzone example.com /etc/bind/forward.example.com
named-checkzone example.com /etc/bind/reverse.example.com
