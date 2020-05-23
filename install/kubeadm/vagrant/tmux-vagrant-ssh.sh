#!/bin/bash

SERVER_NAME="$(./tmux-get-server-name.sh)"

vagrant ssh ${SERVER_NAME}
