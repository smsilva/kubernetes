#!/bin/bash

sudo snap remove microstack --purge

sudo snap install microstack --edge --devmode

sudo microstack init --auto --control

OS_PASSWORD=$(sudo snap get microstack config.credentials.keystone-password)

echo "OS_PASSWORD: ${OS_PASSWORD}"

microstack launch cirros -n test
