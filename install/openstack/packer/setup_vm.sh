#!/bin/sh

set -ex

if [ `id -u` -ne 0 ]; then
  sudo $0
  exit 0
fi

apt-get install git

touch file
