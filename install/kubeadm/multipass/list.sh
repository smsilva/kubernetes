#!/bin/bash

multipass list | grep -E "^dns|^loadbalancer|^master|^worker" | awk '{ print $1,$3 }' | column -t
