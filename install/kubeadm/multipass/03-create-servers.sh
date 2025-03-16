#!/bin/bash
set -e

. ./check-environment-variables.sh

echo ""
echo "Creating Servers"
echo ""

for server_name in ${SERVERS?}; do
  server_prefix_key_name=$(awk -F '-' '{ print $1 }' <<< "${server_name}")

  server_memory_key="${server_prefix_key_name^^}_MEMORY"
  server_cpu_count_key="${server_prefix_key_name^^}_CPU_COUNT"
  server_disk_size_key="${server_prefix_key_name^^}_DISK_SIZE"

  server_cpu_count_value="${!server_cpu_count_key}"
  server_memory_value="${!server_memory_key}"
  server_disk_size_value="${!server_disk_size_key}"
  server_cloud_init_file="${CLOUD_INIT_TARGET_DIRECTORY?}/${server_name?}.yaml"

  echo "${server_name?}.${DOMAIN_NAME?} (vcpu: ${server_cpu_count_value} / mem: ${server_memory_value} / disk: ${server_disk_size_value})"

  if ! ./list.sh | grep --quiet --extended-regexp "${server_name?}"; then
    multipass launch \
      --cpus "${server_cpu_count_value}" \
      --disk "${server_disk_size_value}" \
      --memory "${server_memory_value}" \
      --name "${server_name?}" \
      --cloud-init "${server_cloud_init_file}" && \
    multipass mount "shared/" "${server_name?}":"/shared"
  else
    server_state=$(multipass info "${server_name?}" | sed -n '/^State/ p' | awk '{ print $2 }')

    if [ ${server_state} == "Stopped" ]; then
      multipass start "${server_name?}"
    fi
  fi
  
  echo ""
done
