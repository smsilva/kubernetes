#!/bin/bash
SECONDS=0

SERVERS=$(./list.sh | awk '{ print $1 }')

for SERVER in ${SERVERS?}; do
  echo ${SERVER?}
  multipass delete ${SERVER?}
done

multipass purge

printf 'Elapsed time: %02d:%02d:%02d\n' $((${SECONDS} / 3600)) $((${SECONDS} % 3600 / 60)) $((${SECONDS} % 60))
