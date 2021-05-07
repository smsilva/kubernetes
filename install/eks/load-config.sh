#!/bin/bash

CONFIG_FILE="./cluster.config"

if ! [ -e ${CONFIG_FILE?} ]; then
  cp cluster-sample.config ${CONFIG_FILE?}
fi

source ${CONFIG_FILE?}
