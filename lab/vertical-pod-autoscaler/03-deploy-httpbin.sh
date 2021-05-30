#!/bin/bash

kubectl create -f ${KUBERNETES_AUTOSCALER_LOCAL_GIT_REPOSITORY?}/examples/hamster.yaml
