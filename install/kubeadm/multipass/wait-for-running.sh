#!/bin/bash
MACHINE=$1

machine_status() {
  STATUS=$(multipass info ${MACHINE} | grep "State" | awk '{ print $2 }')

  echo "${STATUS}"
}

STATUS=$(machine_status)

if [ ${STATUS} != "Running" ]; then
  for ((n=1; n <= 20; n++)); do
    STATUS=$(machine_status)

    if [ ${STATUS} == "Running" ]; then
      break
    else
      echo "[${MACHINE}] (${n}): ${STATUS}"
    fi

    sleep 2
  done
fi
