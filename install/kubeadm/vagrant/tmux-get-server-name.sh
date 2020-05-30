#!/bin/bash
WINDOW_NAME=$(tmux list-windows | grep active | awk '{ print $2 }' | sed 's/^all.*/all/')
NODE_NAME=$(tmux list-windows | grep active | awk '{ print $2 }' | sed 's/^masters.*/master/;s/^workers.*/worker/')

export NODES=$(cat .running | grep -E "^master|^worker" | awk '{ print $1 }')

tmux list-panes | while read line; do
  VALUES=$(echo $line | awk '{ print $1 " " $7 }' | sed 's/: %/-/')
  
  LINE_NUMBER=$(echo ${VALUES} | awk -F "-" '{ print $1 }')
  PANE_NUMBER=$(echo ${VALUES} | awk -F "-" '{ print $2 }')
  ACTUAL_PANE_NUMBER=$(echo -n ${TMUX_PANE} | sed 's/%//')
  
  if [[ ((${PANE_NUMBER} == ${ACTUAL_PANE_NUMBER})) ]]; then
    if [[ "${WINDOW_NAME}" == "all" ]]; then
      SERVERS_COUNT=0
      MASTERS_COUNT=0
      WORKERS_COUNT=0
      for node in ${NODES}; do
        ((SERVERS_COUNT++))
        if [[ ${node} =~ ^master ]]; then
          ((MASTERS_COUNT++))
          NODE_NAME="master-${MASTERS_COUNT}"
        else
          ((WORKERS_COUNT++))
          NODE_NAME="worker-${WORKERS_COUNT}"
        fi
        
        if [[ ((${SERVERS_COUNT} == $((${LINE_NUMBER}+1)))) ]]; then
          echo "${NODE_NAME}"
        fi
      done
    else
      echo "${NODE_NAME}-$((${LINE_NUMBER}+1))"
    fi
  fi
done
