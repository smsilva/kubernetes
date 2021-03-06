#!/bin/bash

KUBERNETES_AUTOSCALER_LOCAL_GIT_REPOSITORY="${HOME?}/kubernetes/autoscaler"

! [ -e ${KUBERNETES_AUTOSCALER_LOCAL_GIT_REPOSITORY?} ] && git clone https://github.com/kubernetes/autoscaler.git ${KUBERNETES_AUTOSCALER_LOCAL_GIT_REPOSITORY?}

# Install command
${KUBERNETES_AUTOSCALER_LOCAL_GIT_REPOSITORY?}/vertical-pod-autoscaler/hack/vpa-up.sh

# To print YAML contents with all resources that would be understood by kubectl diff|apply|... commands, you can use
${KUBERNETES_AUTOSCALER_LOCAL_GIT_REPOSITORY?}/vertical-pod-autoscaler/hack/vpa-process-yamls.sh print
