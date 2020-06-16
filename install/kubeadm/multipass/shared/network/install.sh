#!/bin/bash
HOSTNAME=$(hostname -s)

cp "/shared/network/60-extra-interfaces-${HOSTNAME}.yaml" "/etcn/netplan/60-extra-interfaces.yaml"

netplan apply

route -n
