#!/bin/bash

# Configure Vim to use yaml format a little bit better
cat <<EOF >> .vimrc
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
EOF

# bat
BAT_VERSION="0.19.0" && \
BAT_DEB_FILE="bat_${BAT_VERSION}_amd64.deb" && \
wget "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/${BAT_DEB_FILE}" \
  --output-document "${BAT_DEB_FILE}" --quiet && \
sudo dpkg -i "${BAT_DEB_FILE}" &> /dev/null && \
rm "${BAT_DEB_FILE}" && \
echo "alias cat='bat -p'" >> ~/.bash_aliases && \
  source ~/.bash_aliases && \
  bat --version
