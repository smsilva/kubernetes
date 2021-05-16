#!/bin/bash
CONFIG_FILE_NAME=$1

if [ -z "${CONFIG_FILE_NAME}" ]; then
  echo "You must inform a config file."
  exit 1
fi

if ! [ -e "${CONFIG_FILE_NAME?}" ]; then
  echo "The file ${CONFIG_FILE_NAME?} not exists."
  exit 1
fi

. ${CONFIG_FILE_NAME?}
