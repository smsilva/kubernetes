#!/bin/bash
echo "Buckets:                            " && echo "" && (kubectl get Bucket                      ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "CompositeBucket:                    " && echo "" && (kubectl get CompositeBucket             ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Workspace Describe (last 20) lines: " && echo "" && (kubectl describe workspace | tail -20   ) 2>&1 | awk '{ print "  " $0 }' && echo ""
