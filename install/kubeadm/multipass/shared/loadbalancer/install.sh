
cp "/shared/loadbalancer/haproxy.cfg" "/etc/haproxy/haproxy.cfg"

service haproxy restart
set -e

cp "/shared/loadbalancer/haproxy.cfg" "/etc/haproxy/haproxy.cfg"

HAPROXY_CONFIG_FILE="/etc/haproxy/haproxy.cfg"

ADDRES_START=$(awk '{ print $1,$2,$3 }' FS='.' OFS='.' <<< ${ADDRESS})

echo "ADDRESS.............: ${ADDRESS}"
echo "ADDRES_START........: ${ADDRES_START}"
echo "DOMAIN_NAME.........: ${DOMAIN_NAME}"
echo "SERVERS.............: ${SERVERS}"
echo "HOSTNAME............: ${HOSTNAME}"
echo "HAPROXY_CONFIG_FILE.: ${HAPROXY_CONFIG_FILE}"

# apt-get install -y \
#   haproxy

# mv "${HAPROXY_CONFIG_FILE}" "${HOME}/"

# cat <<EOF | tee "${HAPROXY_CONFIG_FILE}"
# frontend apps-nodeport
#     bind ${ADDRESS}:32080,${ADDRESS}:32081
#     mode http
#     default_backend apps-nodeport

# backend apps-nodeport
#     mode http
#     balance roundrobin
#     option tcp-check
# EOF

# for ((line = 1; line <= ${MASTER_NODES_COUNT}; line++)); do
#   echo "    server master-${line} master-${line}.${DOMAIN_NAME}:32080 check fall 3 rise 2" >> "${HAPROXY_CONFIG_FILE}"
# done

# cat <<EOF | tee -a "${HAPROXY_CONFIG_FILE}"

# frontend apps-ingress
#     bind ${ADDRESS}:80
#     mode http
#     stats enable
#     stats auth admin:aneasyvaluetoforget
#     stats hide-version
#     stats show-node
#     stats refresh 60s
#     stats uri /haproxy?stats
#     default_backend apps-ingress

# backend apps-ingress
#     mode http
#     balance roundrobin
#     option tcp-check
# EOF

# for ((line = 1; line <= ${MASTER_NODES_COUNT}; line++)); do
#   echo "    server master-${line} master-${line}.${DOMAIN_NAME}:80 check fall 3 rise 2" >> "${HAPROXY_CONFIG_FILE}"
# done

# cat <<EOF | tee -a "${HAPROXY_CONFIG_FILE}"

# frontend kubernetes-apiserver
#     bind ${ADDRESS}:6443
#     option tcplog
#     mode tcp
#     default_backend kubernetes-apiserver

# backend kubernetes-apiserver
#     mode tcp
#     balance roundrobin
#     option tcp-check
# EOF

# for ((line = 1; line <= ${MASTER_NODES_COUNT}; line++)); do
#   echo "    server master-${line} master-${line}.${DOMAIN_NAME}:6443 check fall 3 rise 2" >> "${HAPROXY_CONFIG_FILE}"
# done

# cat "${HAPROXY_CONFIG_FILE}"

# service haproxy restart
>>>>>>> fb19243 (Configurações para o HAProxy)
