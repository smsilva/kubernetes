#!/bin/bash

declare -A servers
servers['5']="master-1"
servers['6']="worker-1"
servers['7']="worker-2"

INDEX=$(echo -n ${TMUX_PANE} | tr -d "%")

echo -n "${servers[${INDEX}]}"
