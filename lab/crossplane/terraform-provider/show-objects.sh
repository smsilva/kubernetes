#!/bin/bash
echo "Configuration Package: " && echo "" && kubectl get configuration  | awk '{ print "  " $0 }' && echo "" && \
echo "Providers:             " && echo "" && kubectl get provider.pkg   | awk '{ print "  " $0 }' && echo "" && \
echo "Provider Config:       " && echo "" && kubectl get ProviderConfig | awk '{ print "  " $0 }' && echo "" && \
echo "XRDs:                  " && echo "" && kubectl get xrd            | awk '{ print "  " $0 }' && echo "" && \
echo "Compositions:          " && echo "" && kubectl get composition    | awk '{ print "  " $0 }' && echo "" && \
echo "Buckets:               " && echo "" && kubectl get bucket         | awk '{ print "  " $0 }' && echo "" && \
echo "Workspaces (describe): " && echo "" && kubectl describe workspace | tail -20
