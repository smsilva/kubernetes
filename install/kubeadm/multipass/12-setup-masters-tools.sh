#!/bin/bash
. ./check-environment-variables.sh

multipass exec master-1 -- sudo /shared/tools/install.sh
