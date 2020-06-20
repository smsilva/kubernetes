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

exit 0

# HAProxy
# https://www.haproxy.com/blog/the-four-essential-sections-of-an-haproxy-configuration/
FILE="shared/loadbalancer/haproxy.cfg"

cat templates/loadbalancer/haproxy.cfg | envsubst > "${FILE}"

awk '/#.*:.*/ { print $1 }' < "${FILE}" | while read KEY; do
  PORT=$(awk -F ":" '{ print $2 }' <<< "${KEY}")
  LINE_NUMBER=$(sed -n "/${KEY}/=" "${FILE}")

  ./masters.sh | while read SERVER; do
    LINE="server ${SERVER} ${SERVER}.${DOMAIN_NAME}:${PORT}"
    sed -i "${LINE_NUMBER}i\    ${LINE}" "${FILE}"
    LINE_NUMBER=$((${LINE_NUMBER} + 1))
  done

  sed -i "/${KEY}/ d" "${FILE}"
done

cat "${FILE}"

multipass exec loadbalancer -- sudo /shared/loadbalancer/install.sh

# Updat host /etc/hosts file
IP_LOADBALANCER_MULTIPASS=$(mp list | grep -E "^loadbalancer" | awk '{ print $3 }')

sudo sed -i "/.*example.com.*/ d" /etc/hosts
sudo sed -i "s/${IP_LOADBALANCER_ETC_HOSTS}/${IP_LOADBALANCER_MULTIPASS}/g" /etc/hosts

for SERVER in $(echo {haproxy,nginx,foo,bar}.example.com); do
  echo "${IP_LOADBALANCER_MULTIPASS} ${SERVER}" | sudo tee -a /etc/hosts
done

# containerd
for SERVER in $(echo $(./masters.sh) $(./workers.sh)); do
  echo ${SERVER}
  multipass exec ${SERVER} -- sudo /shared/containerd/install.sh
done

printf 'Provision finished in %d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))

echo ""
