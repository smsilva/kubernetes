#!/bin/bash
echo "CompositeResourceDefinition: " && echo "" && (kubectl get CompositeResourceDefinition ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Compositions:                " && echo "" && (kubectl get Composition                 ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Buckets:                     " && echo "" && (kubectl get Bucket                      ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "CompositeBucket:             " && echo "" && (kubectl get CompositeBucket             ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "PODs:                        " && echo "" && (kubectl get POD                         ) 2>&1 | awk '{ print "  " $0 }' && echo ""

POD_NAME="azure-dummy-stack"

pods_logs() {
  kubectl logs ${POD_NAME}
}

if kubectl get pod ${POD_NAME} &> /dev/null; then
echo "POD Logs [${POD_NAME}]:      " && echo "" && (pods_logs                               ) 2>&1 | awk '{ print "  " $0 }' && echo ""
fi
