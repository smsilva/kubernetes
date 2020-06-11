#!/bin/bash
. ./check-environment-variables.sh

multipass restart dns
multipass restart $(echo ${SERVERS} | sed 's/dns //')
