#!/bin/bash

SERVER_NAME="$(./tmux-get-server-name.sh)"

echo "vagrant ssh ${SERVER_NAME}..."
sshvg ${SERVER_NAME}
