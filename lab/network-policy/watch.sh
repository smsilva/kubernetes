#!/bin/bash
watch -n 3 'kubectl get po -A | grep -E "NAME|^olinda|^recife"'
