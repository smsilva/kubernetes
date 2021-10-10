#!/bin/bash
echo "Configuration Package: " && echo "" && (kubectl get configuration ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Providers:             " && echo "" && (kubectl get provider.pkg  ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "XRDs:                  " && echo "" && (kubectl get xrd           ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Compositions:          " && echo "" && (kubectl get composition   ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Provider Config:       " && echo "" && (kubectl get ProviderConfig) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Buckets:               " && echo "" && (kubectl get bucket        ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Workspaces (describe): " && echo "" && (kubectl describe workspace) 2>&1 | awk '{ print "  " $0 }' | tail -20
