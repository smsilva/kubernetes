#!/bin/bash
THIS_SCRIPT="${0}"
THIS_SCRIPT_DIRECTORY=$(dirname "${THIS_SCRIPT}")
export PATH="${THIS_SCRIPT_DIRECTORY?}:${PATH}"

02-install-crossplane-with-helm.sh
