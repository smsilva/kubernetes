#!/bin/bash
EMPTY_RESPONSE="-"

source environment.conf

check_dns_reponse() {
  SERVER=$1
  multipass exec ${SERVER} -- nslookup dns > /dev/null && echo "OK" || echo "FAIL"
}

check_route() {
  SERVER=$1

  if [[ ${SERVER} =~ ^master|^worker ]]; then
    multipass exec ${SERVER} -- route -n | grep --quiet "10.96.0.0" && echo "OK" || echo "FAIL"
  else
    echo "${EMPTY_RESPONSE}"
  fi
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
    multipass exec ${SERVER} -- curl -Is lb:6443 > /dev/null

    COMMAND_RESPONSE_CODE=$?

    if [[ ${COMMAND_RESPONSE_CODE} == 52 ]]; then
      echo "EMPTY RESPONSE"
    else
      if [[ ${COMMAND_RESPONSE_CODE} == 0 ]]; then
        echo "UP"
      else
        echo "CODE: ${COMMAND_RESPONSE_CODE}"
      fi
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

check_images() {
  SERVER=$1

  MASTER_IMAGES="k8s.gcr.io/coredns|k8s.gcr.io/etcd|k8s.gcr.io/kube-apiserver|k8s.gcr.io/kube-controller-manager|k8s.gcr.io/kube-proxy|k8s.gcr.io/kube-scheduler|k8s.gcr.io/pause"
  WORKER_IMAGES="k8s.gcr.io/kube-proxy"

  if [[ ${SERVER} =~ ^master|^worker ]]; then
    if [[ $(check_command ${SERVER} crictl) == "YES" ]]; then
      RUNTIME_ENDPOINT=$(multipass exec ${SERVER} -- sudo crictl config --get runtime-endpoint)

      if [ -n "${RUNTIME_ENDPOINT}" ]; then
        if [[ ${SERVER} =~ ^master ]]; then
          IMAGES="${MASTER_IMAGES}"
        else
          IMAGES="${WORKER_IMAGES}"
        fi

        IMAGES_WITHOUT_SEPARATOR=$(sed 's/|//g' <<< "${IMAGES}")
        EXPECTED_IMAGE_COUNT=$((${#IMAGES} - ${#IMAGES_WITHOUT_SEPARATOR} + 1))

        IMAGE_COUNT=$(multipass exec ${SERVER} -- sudo crictl images | sed 1d | awk '{ print $1 }' | grep -E "${IMAGES}" | wc -l)

        if (( ${IMAGE_COUNT} < ${EXPECTED_IMAGE_COUNT} )); then
          echo "AVAILABLE/EXPECTED: ${IMAGE_COUNT}/${EXPECTED_IMAGE_COUNT}"
        else
          echo "OK (${IMAGE_COUNT}/${EXPECTED_IMAGE_COUNT})"
        fi
      else
        echo "runtime-endpoint not set"
      fi
    else
      echo "CRICTL NOT INSTALLED"
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
    VALIDATION_KUBELET=$(check_command ${SERVER} kubelet)
    [[ ${SERVER} =~ ^master ]] && VALIDATION_KUBECTL=$(check_command ${SERVER} kubectl) || VALIDATION_KUBECTL="${EMPTY_RESPONSE}"
    VALIDATION_IMAGES=$(check_images ${SERVER})
  
    echo "${SERVER};${VALIDATION_DNS};${VALIDATION_ROUTE};${VALIDATION_CONTAINERD};${VALIDATION_CONTROL_PLANE_PORT};${VALIDATION_KUBEADM};${VALIDATION_KUBELET};${VALIDATION_KUBECTL};${VALIDATION_IMAGES}"
  done
}

HEADER_LINE="SERVER;DNS;ROUTE;CONTAINERD;LB_PORT_6443;KUBEADM;KUBELET;KUBECTL;IMAGES"

SECONDS=0

execute | sed -e "1i${HEADER_LINE}" | column -t -s ";"

echo ""

printf 'Validation elapsed time: %02d:%02d:%02d\n' $((${SECONDS} / 3600)) $((${SECONDS} % 3600 / 60)) $((${SECONDS} % 60))
