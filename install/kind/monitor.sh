#!/bin/bash
watch -n3 'kubectl get nodes | awk "{ print \$1,\$2,\$3 }" | column -t && echo "" && \
kubectl get deploy,rs && echo "" && \
kubectl get pods -o wide | awk "{ print \$1,\$2,\$3,\$4,\$5,\$6,\$7 }" | column -t && echo "" && \
kubectl get ep nginx'
