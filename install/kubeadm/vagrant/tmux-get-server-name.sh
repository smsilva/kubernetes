#!/bin/bash
NODE_NAME=$(tmux list-windows | grep active | awk '{ print $2 }' | sed 's/^masters.*/master/;s/^workers.*/worker/')

tmux list-panes | while read line; do
  VALUES=$(echo $line | awk '{ print $1 " " $7 }' | sed 's/: %/-/')
  
  LINE_NUMBER=$(echo ${VALUES} | awk -F "-" '{ print $1 }')
  PANE_NUMBER=$(echo ${VALUES} | awk -F "-" '{ print $2 }')
  ACTUAL_PANE_NUMBER=$(echo -n ${TMUX_PANE} | sed 's/%//')
  
  if [[ ((${PANE_NUMBER} == ${ACTUAL_PANE_NUMBER})) ]]; then
    echo "${NODE_NAME}-$((${LINE_NUMBER}+1))"
  fi
done
