#!/bin/bash

# Install the Dapr CLI
# https://docs.dapr.io/getting-started/install-dapr-cli/

if ! which dapr &> /dev/null; then
  echo "Need to download and install dapr CLI..."
  
  wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash

  dapr
fi
