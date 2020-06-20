#!/bin/bash
SECONDS=0

if [ ! -e environment.conf ]; then
  echo "You should create a environment.conf file. Try to start cloning templates/environment.conf.sample file."
  echo ""
  echo "  cp templates/environment.conf.sample environment.conf"
  echo ""

. ./generate-cloud-init-files.sh
. ./create-servers.sh
$(./set-environment-variables-with-servers-information.sh)
. ./setup-netplan.sh
. ./setup-hosts-file.sh
. ./setup-dns-bind.sh
. ./setup-loadbalancer-haproxy.sh
. ./update-system-config.sh
. ./setup-cri-containerd.sh
. ./update-host-etc-hosts.sh

printf 'Provision finished in %d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))
