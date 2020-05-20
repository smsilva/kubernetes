#!/bin/bash
IP_DNS=$1

sed -i -e "s/#DNS=/DNS=${IP_DNS} 8.8.8.8/" /etc/systemd/resolved.conf

service systemd-resolved restart
