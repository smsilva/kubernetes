#!/bin/bash
DESCRIBE_CLUSTER_LINES=5

show_configmaps_data() {
  kubectl get cm -o json | jq '.items | .[] | {name: .metadata.name, data: .data}'
}

echo "Clusters:                                       " && echo "" && ( kubectl get Cluster                                        ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "ConfigMaps:                                     " && echo "" && ( kubectl get ConfigMap                                      ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Jobs                                            " && echo "" && ( kubectl get Jobs                                           ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
#echo "ConfigMaps Data:                                " && echo "" && ( show_configmaps_data                                       ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Describe Clusters (-${DESCRIBE_CLUSTER_LINES}): " && echo "" && ( kubectl describe Cluster | tail -${DESCRIBE_CLUSTER_LINES} ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo ""
