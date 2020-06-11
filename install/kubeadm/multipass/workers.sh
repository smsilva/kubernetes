#!/bin/bash

./list.sh | awk '{ print $1 }' | grep -E "^worker"
