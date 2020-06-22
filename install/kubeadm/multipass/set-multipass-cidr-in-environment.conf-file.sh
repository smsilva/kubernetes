#!/bin/bash
primary_create() {
  multipass start primary
}

primary_start() {
  multipass start primary
}

primary_stop() {
  multipass stop primary
}

primary_status() {
  STATUS=$(multipass info primary | grep "State" | awk '{ print $2 }')

  echo "${STATUS}"
}

config_environment_conf_file() {
  MULTIPASS_PRIMARY_MACHINE_IP=$(multipass list | grep -E "^primary" | awk '{ print $3 }')
  MULTIPASS_PRIMARY_MACHINE_IP_BASE="${MULTIPASS_PRIMARY_MACHINE_IP%.*}"

  echo "MULTIPASS_PRIMARY_MACHINE_IP......: ${MULTIPASS_PRIMARY_MACHINE_IP}" && \
  echo "MULTIPASS_PRIMARY_MACHINE_IP_BASE.: ${MULTIPASS_PRIMARY_MACHINE_IP_BASE}" && \

  sed --in-place "/.*IP_NETWORK=.*/ s/=.*/=\"${MULTIPASS_PRIMARY_MACHINE_IP_BASE}.0\/24\"/" environment.conf

  echo "done"
}

if ! multipass list | grep -E "^primary" -q; then
  primary_create
fi

STATUS=$(primary_status)

if [ ${STATUS} == "Stopped" ]; then
  primary_start

  for ((n=1; n <= 10; n++)); do
    STATUS=$(primary_status)

    if [ ${STATUS} == "Running" ]; then
      break
    else
      echo "Primary Multipass Machine Status (${n}): ${STATUS}"
    fi

    sleep 2
  done
fi

config_environment_conf_file

primary_stop
