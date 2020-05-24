#!/bin/bash
cd /tmp
curl -fsSL https://get.docker.com -o get-docker.sh
sh /tmp/get-docker.sh
usermod -aG docker vagrant
