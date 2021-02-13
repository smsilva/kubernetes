#!/bin/bash
watch -n3 'kubectl get nodes -L disktype | awk "{ print \$1,\$2,\$3,\$6 }" | column -t && echo "" && \
kubectl get deploy && echo "" && \
kubectl get pods -o wide | awk "{ print \$1,\$2,\$3,\$4,\$5,\$6,\$7 }" | column -t && echo "" && \
echo "Endpoints available: $(kubectl get ep nginx -o yaml | grep ' ip:' | wc -l)" && echo "" && \
kubectl get pdb'
