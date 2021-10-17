#!/bin/bash
DESCRIBE_CLUSTER_LINES=5

show_configmaps_data() {
#  kubectl get cm -o json | jq '.items | .[] | {name: .metadata.name, server: .data.server}'
  kubectl get cm -o json | jq '.items[].data.server' --raw-output
}

show_secrets() {
  kubectl get Secrets -A | grep -E "NAME|crossplane" | column -t
}

describe_clusters() {
  kubectl describe Cluster | tail -${DESCRIBE_CLUSTER_LINES}
}

DESCRIBE_CLUSTERS="Describe Clusters (-${DESCRIBE_CLUSTER_LINES}):"
SHOW_CONFIG_MAPS="ConfigMaps Data (.data.server):"

echo "Clusters:             " && echo "" && ( kubectl get Cluster    --show-labels ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Objects:              " && echo "" && ( kubectl get Objects    --show-labels ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "ConfigMaps:           " && echo "" && ( kubectl get ConfigMaps --show-labels ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Pods:                 " && echo "" && ( kubectl get Pods       --show-labels ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "${SHOW_CONFIG_MAPS}   " && echo "" && ( show_configmaps_data                 ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "${DESCRIBE_CLUSTERS}  " && echo "" && ( describe_clusters                    ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo ""
