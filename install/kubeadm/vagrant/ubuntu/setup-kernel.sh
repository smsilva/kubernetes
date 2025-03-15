#!/bin/bash
cat <<EOF > /etc/modules-load.d/10-kubernetes.conf
br_netfilter
ip_vs
ip_vs_rr
ip_vs_sh
ip_vs_wrr
nf_conntrack
overlay
EOF

modprobe overlay
modprobe br_netfilter

systemctl restart systemd-modules-load.service

# Setup required sysctl params, these persist across reboots.
cat <<EOF > /etc/sysctl.d/10-kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.disable_ipv6      = 1
net.ipv6.conf.default.disable_ipv6  = 1
net.ipv6.conf.lo.disable_ipv6       = 1
EOF

sysctl --system
