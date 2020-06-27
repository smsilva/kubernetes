#!/bin/bash
EMPTY_RESPONSE="-"

check_dns_reponse() {
  SERVER=$1
  multipass exec ${SERVER} -- nslookup dns > /dev/null && echo "OK" || echo "FAIL"
}

check_route() {
  SERVER=$1
  multipass exec ${SERVER} -- route -n | grep --quiet "10.96.0.0" && echo "OK" || echo "FAIL"
}

check_containerd() {
  SERVER=$1

  if [[ ${SERVER} =~ ^master|^worker ]]; then
    if multipass exec ${SERVER} -- which containerd > /dev/null; then
      multipass exec ${SERVER} -- containerd --version | awk '{ print $3 }' || echo "FAIL"
    else
      echo "NOT INSTALLED"
    fi
  else
    echo "${EMPTY_RESPONSE}"
  fi
}

check_control_plane_port() {
  SERVER=$1

  if [[ ${SERVER} =~ ^master|^worker ]]; then
    multipass exec ${SERVER} -- curl -Is lb:6443

    COMMAND_RESPONSE_CODE=$?

    if [[ ${COMMAND_RESPONSE_CODE} == 52 ]]; then
      echo "EMPTY RESPONSE"
    else
      echo "CODE: ${COMMAND_RESPONSE_CODE}"
    fi
  else
    echo "${EMPTY_RESPONSE}"
  fi
}

check_command() {
  SERVER=$1
  COMMAND=$2

  if [[ ${SERVER} =~ ^master|^worker ]]; then
    if multipass exec ${SERVER} -- which ${COMMAND} > /dev/null; then
      echo "YES"
    else
      echo "NO"
    fi
  else
    echo "${EMPTY_RESPONSE}"
  fi
}

execute() {
  for SERVER in ${SERVERS}; do
    VALIDATION_DNS=$(check_dns_reponse ${SERVER})
    VALIDATION_ROUTE=$(check_route ${SERVER})
    VALIDATION_CONTAINERD=$(check_containerd ${SERVER})
    VALIDATION_CONTROL_PLANE_PORT=$(check_control_plane_port ${SERVER})
    VALIDATION_KUBEADM=$(check_command ${SERVER} kubeadm)
  
    echo "${SERVER};${VALIDATION_DNS};${VALIDATION_ROUTE};${VALIDATION_CONTAINERD};${VALIDATION_CONTROL_PLANE_PORT};${VALIDATION_KUBEADM}"
  done
}

HEADER_LINE_1="SERVER;DNS;ROUTE;CONTAINERD;LB_PORT_6443;KUBEADM"
HEADER_LINE_2="=============;=====;=====;=============;==============;======="

execute | sed -e "1i${HEADER_LINE_1}" -e "1i${HEADER_LINE_2}" | column -t -s ";"
