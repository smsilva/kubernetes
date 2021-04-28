#!/bin/bash
watch -n 2 kubectl get deploy,pods,svc,ep -o wide

