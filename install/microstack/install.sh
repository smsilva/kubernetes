#!/bin/bash

sudo snap remove microstack --purge

sudo snap install microstack --edge --devmode

sudo microstack init \
  --auto \
  --control \
  --debug \
  --default-source-ip 192.168.68.107

OS_PASSWORD=$(sudo snap get microstack config.credentials.keystone-password)

echo "OS_PASSWORD: ${OS_PASSWORD}"

microstack launch cirros -n test

microstack.openstack image create \
  --public \
  --disk-format qcow2 \
  --min-disk 20 \
  --min-ram 2048 \
  --file ubuntu-focal-server-cloud-amd64-20210810.img \
  ubuntu-focal-server-cloud-amd64-20210810
