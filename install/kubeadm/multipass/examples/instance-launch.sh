#!/bin/bash
SECONDS=0

INSTANCE_NAME="hal-9000"
CLOUD_INI_FILE="${INSTANCE_NAME}-cloud-init.yaml"

cat <<EOF > "${INSTANCE_NAME}-cloud-init.yaml"
#cloud-config
hostname: hal-9000

write_files:
- encoding: b64
  content: IyEvYmluL3NoCmNhdCA8PEVPRgouLS0tLS0tLS0tLgp8Li0tLS0tLS0ufAp8fEhBTDkwMDB8fAp8Jy0tLS0tLS0nfAp8ICAgICAgICAgfAp8ICAgICAgICAgfCAiSSdtIHNvcnJ5IERhdmUuIgp8IC4tLiAgICAgfCAiSSdtIGFmcmFpZCBJIGNhbid0IGRvIHRoYXQuIgp8ICggbyApICAgfAp8IFxgLScgICAgIHwKfF9fX19fX19fX3wKfColKiUqJSolKnwKfCUqJSolKiUqJXwKfColKiUqJSolKnwKJz09PT09PT09PScKCkVPRgoK
  owner: root:root
  path: /etc/update-motd.d/99-hello
  permissions: '0755'
EOF

multipass launch \
  --cpus "1" \
  --disk "50G" \
  --mem "1024M" \
  --name "${INSTANCE_NAME}" \
  --cloud-init "${CLOUD_INI_FILE}" && \
multipass mount "./" "${INSTANCE_NAME}":"/shared"

printf 'Elapsed time: %02d:%02d:%02d %s\n' $((${SECONDS} / 3600)) $((${SECONDS} % 3600 / 60)) $((${SECONDS} % 60)) "${MESSAGE}"
