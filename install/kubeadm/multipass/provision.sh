#!/bin/bash
SECONDS=0

if [ ! -e environment.conf ]; then
  echo "You should create a environment.conf file. Try to start cloning templates/environment.conf.sample file."
  echo ""
  echo "  cp templates/environment.conf.sample environment.conf"
  echo ""

SERVERS=$(echo dns loadbalancer master-{1..3} worker-{1..3})

for SERVER in ${SERVERS}; do
  CLOUD_INIT_TEMPLATE_NAME=$(awk -F '-' '{ print $1 }' <<< "${SERVER}")
  CLOUD_INIT_FILE="cloud-init/${SERVER}.yaml"

  export SERVER_HOST_NAME="${SERVER}"
  export CLOUD_INIT_IP_DNS=$(multipass list | grep -E "^dns" | awk '{ print $3 }')

  cat "cloud-init/templates/${CLOUD_INIT_TEMPLATE_NAME}.yaml" | envsubst > "${CLOUD_INIT_FILE}"

  SERVER_MEMORY_KEY="${CLOUD_INIT_TEMPLATE_NAME^^}_MEMORY"
  SERVER_CPU_COUNT_KEY="${CLOUD_INIT_TEMPLATE_NAME^^}_CPU_COUNT"
  SERVER_DISK_SIZE_KEY="${CLOUD_INIT_TEMPLATE_NAME^^}_DISK_SIZE"

  echo "Server...............................: ${SERVER}.${DOMAIN_NAME}"
  echo "cloud-init file......................: ${CLOUD_INIT_FILE}"
  echo "Memory...............................: ${!SERVER_MEMORY_KEY}"
  echo "vCPU Count...........................: ${!SERVER_CPU_COUNT_KEY}"
  echo "Disk Size............................: ${!SERVER_DISK_SIZE_KEY}"
  echo "DNS Server IP........................: ${CLOUD_INIT_IP_DNS}"

  multipass launch \
    --cpus "${!SERVER_CPU_COUNT_KEY}" \
    --disk "${!SERVER_DISK_SIZE_KEY}" \
    --mem "${!SERVER_MEMORY_KEY}" \
    --name "${SERVER}" \
    --cloud-init "${CLOUD_INIT_FILE}" && \
  multipass mount shared/ "${SERVER}":/shared

  echo ""
done

printf 'Server were created in %d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))

[ -e shared/dns/servers.conf ] && rm shared/dns/servers.conf

./list.sh | while read line; do
  SERVER_NAME=$(awk '{ print $1 }' <<< "${line}" | sed 's/-/_/g')
  SERVER_IP=$(awk '{ print $2 }' <<< "${line}")
  SERVER_IP_LAST_OCTET=${SERVER_IP##*.}

  echo "export IP_${SERVER_NAME^^}=${SERVER_IP}" >> shared/dns/servers.conf
  echo "export IP_LAST_OCTET_${SERVER_NAME^^}=${SERVER_IP_LAST_OCTET}" >> shared/dns/servers.conf
  echo "" >> shared/dns/servers.conf
done

source shared/dns/servers.conf

export DOLLAR='$'

cat templates/dns/named.conf.options | envsubst > shared/dns/named.conf.options
cat templates/dns/named.conf.local | envsubst > shared/dns/named.conf.local
cat templates/dns/forward.domain | envsubst > shared/dns/"forward.${DOMAIN_NAME}"
cat templates/dns/reverse.domain | envsubst > shared/dns/"reverse.${DOMAIN_NAME}"
cat templates/dns/install.sh | envsubst > shared/dns/install.sh

./list.sh | grep -E "^master|^worker" | while read line; do
  SERVER_NAME=$(awk '{ print $1 }' <<< "${line}" | sed 's/-/_/g' | tr [a-z] [A-Z])
  SERVER_NAME_DNS="$(awk '{ print $1 }' <<< "${line}")"
  IP_KEY="IP_${SERVER_NAME}"
  IP_LAST_OCTET_KEY="IP_LAST_OCTET_${SERVER_NAME}"
  IP_VALUE="${!IP_KEY}"
  IP_LAST_OCTET_VALUE="${!IP_LAST_OCTET_KEY}"
  echo "${SERVER_NAME_DNS}     IN       A       ${IP_VALUE}" >> shared/dns/"forward.${DOMAIN_NAME}"
  echo "${IP_LAST_OCTET_VALUE}      IN      PTR     ${SERVER_NAME_DNS}.${DOMAIN_NAME}." >> shared/dns/"reverse.${DOMAIN_NAME}"
done

multipass exec dns -- sudo /shared/dns/install.sh

[ -e shared/dns/setup-resolv.conf-all.sh ] && rm shared/dns/setup-resolv.conf-all.sh
[ -e shared/update-system-config-all.sh ] && rm shared/update-system-config-all.sh

./list.sh | awk '{ print $1 }' | grep -v -E "^dns" | while read SERVER; do
  echo "echo ${SERVER}" >> shared/dns/setup-resolv.conf-all.sh
  echo "multipass exec ${SERVER} -- sudo /shared/setup-resolv.conf.sh ${CLOUD_INIT_IP_DNS}" >> shared/dns/setup-resolv.conf-all.sh
  echo "multipass exec ${SERVER} -- sudo /shared/update-system-config.sh" >> shared/update-system-config-all.sh
done

chmod +x shared/dns/setup-resolv.conf-all.sh
chmod +x shared/update-system-config-all.sh

shared/dns/setup-resolv.conf-all.sh
shared/update-system-config-all.sh

# HAProxy
FILE="shared/loadbalancer/haproxy.cfg"

cat templates/loadbalancer/haproxy.cfg | envsubst > "${FILE}"

awk '/#.*:.*/ { print $1 }' < "${FILE}" | while read KEY; do
  PORT=$(awk -F ":" '{ print $2 }' <<< "${KEY}")
  LINE_NUMBER=$(sed -n "/${KEY}/=" "${FILE}")

  ./masters.sh | while read SERVER; do
    LINE="server ${SERVER} ${SERVER}.${DOMAIN_NAME}:${PORT} check fall 3 rise 2"
    sed -i "${LINE_NUMBER}i\    ${LINE}" "${FILE}"
    LINE_NUMBER=$((${LINE_NUMBER} + 1))
  done

  sed -i "/${KEY}/ d" "${FILE}"
done

bat "${FILE}"

MASTERS=$(./masters.sh | xargs | sed 's/ /;/g')

mp exec loadbalancer -- sudo /shared/loadbalancer/install.sh ${IP_LOADBALANCER} ${DOMAIN_NAME} ${MASTERS}
