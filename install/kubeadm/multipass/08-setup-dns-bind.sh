#!/bin/bash
. ./check-environment-variables.sh

FORWARD_FILE="forward.${DOMAIN_NAME?}"
REVERSE_FILE="reverse.${DOMAIN_NAME?}"

cat templates/dns/named.conf.options | envsubst > shared/dns/named.conf.options
cat templates/dns/named.conf.local | envsubst > shared/dns/named.conf.local
cat templates/dns/forward.domain | envsubst > shared/dns/${FORWARD_FILE?}
cat templates/dns/reverse.domain | envsubst > shared/dns/${REVERSE_FILE?}

for SERVER in ${SERVERS?}; do
  if [[ ${SERVER?} =~ ^master|^worker ]]; then
    SERVER_NAME_FOR_KEY=$(echo ${SERVER?} | sed 's/-/_/g' | tr [a-z] [A-Z])
    IP_KEY="IP_${SERVER_NAME_FOR_KEY?}"
    IP_LAST_OCTET_KEY="IP_LAST_OCTET_${SERVER_NAME_FOR_KEY?}"
    IP_VALUE="${!IP_KEY}"
    IP_LAST_OCTET_VALUE="${!IP_LAST_OCTET_KEY}"

    echo "${SERVER?}     IN       A       ${IP_VALUE?}" >> shared/dns/${FORWARD_FILE?}
    echo "${IP_LAST_OCTET_VALUE?}      IN      PTR     ${SERVER?}.${DOMAIN_NAME?}." >> shared/dns/${REVERSE_FILE?}
  fi
done

multipass exec dns -- sudo /shared/dns/install.sh ${DOMAIN_NAME?}
