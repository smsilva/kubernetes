#!/bin/bash

NETWORK_INTERFACE_NAME='enp0s8' && \
LOCAL_IP_ADDRESS="$(ip -4 addr show ${NETWORK_INTERFACE_NAME} | grep "inet" | head -1 | awk '{print $2}' | cut -d/ -f1)" && \
echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo ""

# Add Route
ip route add 10.96.0.0/16 dev enp0s8 src ${LOCAL_IP_ADDRESS}
