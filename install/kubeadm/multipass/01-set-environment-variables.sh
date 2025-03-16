#!/bin/bash
primary_status() {
  multipass info primary | grep "State" | awk '{ print $2 }'
}

config_environment_conf_file() {
  multipass_primary_machine_ip=$(multipass list | grep -E "^primary" | awk '{ print $3 }')
  multipass_primary_machine_ip_base="${multipass_primary_machine_ip%.*}"

  sed --in-place "/.*IP_NETWORK=.*/ s/=.*/=\"${multipass_primary_machine_ip_base}.0\/24\"/" environment.conf
}

if grep --quiet "THIS_VALUE_WILL_BE_REPLACED_AUTOMATICALLY" environment.conf; then
  if ! multipass list | grep -E "^primary" -q; then
    multipass start primary
  fi
  
  status=$(primary_status)
  
  if [ ${status} == "Stopped" ]; then
    multipass start primary
  
    for ((n=1; n <= 10; n++)); do
      status=$(primary_status)
  
      if [ ${status} == "Running" ]; then
        break
      else
        echo "Primary Multipass Machine Status (${n}): ${status}"
      fi
  
      sleep 2
    done
  fi
  
  config_environment_conf_file
  
  multipass stop primary
fi

source ./environment.conf
