#!/bin/bash
#echo "Provider:                    " && echo "" && (kubectl get Provider                    ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "ProviderConfig:              " && echo "" && (kubectl get ProviderConfig              ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "CompositeResourceDefinition: " && echo "" && (kubectl get CompositeResourceDefinition ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Compositions:                " && echo "" && (kubectl get Composition                 ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Buckets:                     " && echo "" && (kubectl get Bucket                      ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "CompositeBucket:             " && echo "" && (kubectl get CompositeBucket             ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "PODs:                        " && echo "" && (kubectl get POD                         ) 2>&1 | awk '{ print "  " $0 }' && echo ""

kubectl describe workspace

