#!/bin/bash

sed -i -e 's/#DNS=/DNS=192.168.10.2 8.8.8.8/' /etc/systemd/resolved.conf

service systemd-resolved restart
