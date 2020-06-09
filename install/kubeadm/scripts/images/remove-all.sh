#!/bin/bash

# Remove All Images
sudo ctr images ls | sed '1d' | awk '{ print $1 }' | while read line; do sudo ctr images remove ${line}; done
sudo crictl images | sed '1d' | awk '{ print $3 }' | while read line; do sudo crictl rmi ${line}; done
sudo ctr images ls
sudo crictl images
