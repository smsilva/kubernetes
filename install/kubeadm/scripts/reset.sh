#!/bin/bash
sudo kubeadm reset --force && \
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
