#!/bin/bash
watch -n 3 'kubectl get po,svc -A | grep -E "NAME|^olinda|^recife"'