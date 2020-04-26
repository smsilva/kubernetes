#!/bin/bash

sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
# apt-get update -y && \
# apt-get upgrade -y && \
# apt-get dist-upgrade -y && \
# apt-get autoremove
