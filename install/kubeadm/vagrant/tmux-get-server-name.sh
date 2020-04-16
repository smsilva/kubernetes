#!/bin/bash

declare -A servers
servers['0']="master-1"
servers['1']="worker-1"
servers['2']="worker-2"

INDEX=$(echo -n ${TMUX_PANE} | tr -d "%")

echo -n "${servers[${INDEX}]}"
