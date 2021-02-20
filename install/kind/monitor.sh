#!/bin/bash
watch -n 3 'kubectl get deploy && echo "" && \
kubectl get pods -o wide | awk "{ print \$1,\$2,\$3,\$4,\$5,\$6,\$7 }" | column -t && echo "" && \
echo "Endpoints available: $(kubectl get ep httpbin -o yaml | grep ' ip:' | wc -l)" && echo "" && \
kubectl get ingress'
