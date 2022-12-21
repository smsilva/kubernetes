#!/bin/bash
WEAVE_NET_CNI_PLUGIN_FILE="weave-net-cni-plugin.yaml" && \
WEAVE_NET_CNI_PLUGIN_URL="https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml" && \
wget "${WEAVE_NET_CNI_PLUGIN_URL}" \
  --quiet \
  --output-document "${WEAVE_NET_CNI_PLUGIN_FILE}"

cat <<EOF > patch.yaml
                - name: IPALLOC_RANGE
                  value: 10.30.0.0/16
EOF

INSERT_LINE=$(( $(sed -n '/INIT_CONTAINER/=' ${WEAVE_NET_CNI_PLUGIN_FILE}) - 1 ))

sed -i "${INSERT_LINE?}r patch.yaml" ${WEAVE_NET_CNI_PLUGIN_FILE}

grep INIT_CONTAINER -B 2 -A 1 ${WEAVE_NET_CNI_PLUGIN_FILE}

kubectl apply -f ${WEAVE_NET_CNI_PLUGIN_FILE}
