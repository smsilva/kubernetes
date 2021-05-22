#!/bin/bash

# Configure Vim to use yaml format a little bit better
cat <<EOF >> ~/.vimrc
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
EOF

# # bat
# BAT_VERSION="0.15.1" && \
# BAT_DEB_FILE="bat_${BAT_VERSION}_amd64.deb" && \
# wget "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/${BAT_DEB_FILE}" \
#   --output-document "${BAT_DEB_FILE}" && \
# sudo dpkg -i "${BAT_DEB_FILE}" && rm "${BAT_DEB_FILE}" && \
# echo "alias cat='bat -p'" >> /home/ubuntu/.bash_aliases && bat --version

# # jq
# sudo apt-get install jq --yes && jq --version

# # yq
# sudo snap install yq

# yq --version

# echo "alias yq='yq -C -P'" >> /home/ubuntu/.bashrc
