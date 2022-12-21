#!/bin/bash

SECONDS=0

PARALLEL_EXECUTIONS="6"

vagrant status \
| grep virtualbox \
| awk '{ print $1 }' \
| xargs --max-procs ${PARALLEL_EXECUTIONS?} -I {} vagrant up {} 

printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))
