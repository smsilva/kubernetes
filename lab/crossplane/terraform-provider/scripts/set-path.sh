#!/bin/bash
THIS_SCRIPT="${0}"
THIS_SCRIPT_DIRECTORY=$(dirname "${THIS_SCRIPT}")

PATH_TO_ADD="$(pwd)/${THIS_SCRIPT_DIRECTORY}"

echo "export PATH=${PATH_TO_ADD}:${PATH}"
