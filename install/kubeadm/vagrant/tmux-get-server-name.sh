#!/bin/bash

declare -A servers
servers['6']="master-1"
servers['7']="master-2"
servers['8']="worker-1"
servers['9']="worker-2"

INDEX=$(echo -n ${TMUX_PANE} | tr -d "%")

echo -n "${servers[${INDEX}]}"