#!/bin/bash
SECONDS=0

multipass start $(./list.sh | awk '{ print $1 }' | xargs)

printf 'Start elapsed time: %02d:%02d:%02d\n' $((${SECONDS} / 3600)) $((${SECONDS} % 3600 / 60)) $((${SECONDS} % 60))
