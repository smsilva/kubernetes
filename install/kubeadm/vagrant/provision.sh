#!/bin/bash

SECONDS=0

MACHINES=$*

for machine in ${MACHINES}; do
  vagrant up ${machine}
done

printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))
