#!/bin/bash

declare -A servers

servers['7']="master-1"
servers['8']="master-2"
servers['9']="master-3"
servers['10']="worker-1"
servers['11']="worker-2"

INDEX=$(echo -n ${TMUX_PANE} | tr -d "%")

echo -n "${servers[${INDEX}]}"

tmux list-panes | while read line; do
  VALUES=$(echo $line | awk '{ print $1 " " $7 }' | sed 's/: %/-/')
  LINE=$(echo ${VALUES} | awk -F "-" '{ print $1 }')
  echo "${VALUES} - PANE: ${TMUX_PANE}"


done
