#!/bin/bash
SECONDS=0

if [ ! -e environment.conf ]; then
  echo "You should create a environment.conf file. Try to start cloning templates/environment.conf.sample file."
  echo ""
  echo "  cp templates/environment.conf.sample environment.conf"
  echo ""

  exit 1
fi

log_time() {
  MESSAGE=$1
  
  printf '[%02d:%02d:%02d] - %s\n' $((${SECONDS} / 3600)) $((${SECONDS} % 3600 / 60)) $((${SECONDS} % 60)) "${MESSAGE}"

  echo ""
}

provision() {
  . ./01-set-environment-variables.sh
  . ./02-generate-cloud-init-files.sh
  . ./03-create-servers.sh;                                       log_time "servers created"
  $(./04-set-environment-variables-with-servers-information.sh)
  . ./05-setup-netplan.sh
  . ./06-setup-hosts-file.sh
  . ./07-update-servers.sh;                                       log_time "servers updated"
  . ./08-setup-dns-bind.sh;                                       log_time "bind 9 configured"
  . ./09-restart-servers.sh;                                      log_time "servers restarted"
  . ./10-setup-loadbalancer-haproxy.sh;                           log_time "haproxy configured"
  . ./11-update-system-config.sh                                  log_time "system config updated"
  . ./12-update-local-etc-hosts.sh
  . ./13-setup-cri-containerd.sh                                  log_time "containerd installed"
  . ./14-setup-masters-tools.sh                                   log_time "master tools installed"

  log_time "provision process is done"
}

provision
