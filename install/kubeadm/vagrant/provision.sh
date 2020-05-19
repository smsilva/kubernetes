#!/bin/bash

SECONDS=0

vagrant up --no-parallel

printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))
